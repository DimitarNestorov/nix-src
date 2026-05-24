#include "nix/store/builtins.hh"

#include <filesystem>
#include <wasmtime.hh>

using namespace wasmtime;

namespace nix {

std::string remove_last_path_element(const std::string & path)
{
    std::filesystem::path p(path);
    return p.parent_path().string();
}

std::string last_path_element(const std::string & path)
{
    std::filesystem::path p(path);
    return p.filename();
}

using ValueId = uint32_t;

template<typename T, typename E = Error>
T unwrap(Result<T, E> && res)
{
    if (res)
        return res.ok();
    throw Error(res.err().message());
}

static Engine & getEngine()
{
    static Engine engine = []() {
        wasmtime::Config config;
        config.pooling_allocation_strategy(PoolAllocationConfig());
        config.memory_init_cow(true);
        return Engine(std::move(config));
    }();
    return engine;
}

static std::string_view span2string(std::span<uint8_t> s)
{
    return std::string_view((char *) s.data(), s.size());
}

// FIXME: move to wasmtime C++ wrapper.
class InstancePre
{
    WASMTIME_OWN_WRAPPER(InstancePre, wasmtime_instance_pre);

public:
    TrapResult<Instance> instantiate(wasmtime::Store::Context cx)
    {
        wasmtime_instance_t instance;
        wasm_trap_t * trap = nullptr;
        auto * error = wasmtime_instance_pre_instantiate(ptr.get(), cx.capi(), &instance, &trap);
        if (error != nullptr) {
            return TrapError(wasmtime::Error(error));
        }
        if (trap != nullptr) {
            return TrapError(Trap(trap));
        }
        return Instance(instance);
    }
};

TrapResult<InstancePre> instantiate_pre(Linker & linker, const Module & m)
{
    wasmtime_instance_pre_t * instance_pre;
    auto * error = wasmtime_linker_instantiate_pre(linker.capi(), m.capi(), &instance_pre);
    if (error != nullptr) {
        return TrapError(wasmtime::Error(error));
    }
    return InstancePre(instance_pre);
}

static void regFuns(Linker & linker, bool useWasi);

struct NixWasmInstancePre
{
    Engine & engine = getEngine();
    std::string name;
    bool useWasi = false;
    InstancePre instancePre;

    InstancePre compile(std::span<uint8_t> bytes)
    {
        // Compile the module
        auto module = unwrap(Module::compile(engine, bytes));

        // Create linker with appropriate WASI support
        Linker linker(engine);
        unwrap(linker.define_wasi());
        regFuns(linker, true);

        return unwrap(instantiate_pre(linker, module));
    }

    NixWasmInstancePre(std::string_view wat)
        : name("<inline wat>")
        , instancePre([&] {
            auto wasm = unwrap(wat2wasm(wat));
            return compile(std::span<uint8_t>(wasm));
        }())
    {
    }
};

struct NixWasmInstance
{
    ref<NixWasmInstancePre> pre;
    wasmtime::Store wasmStore;
    wasmtime::Store::Context wasmCtx;
    Instance instance;
    Memory memory_;

    std::exception_ptr ex;

    std::optional<std::string> functionName;

    std::string logPrefix;

    NixWasmInstance(ref<NixWasmInstancePre> _pre)
        : pre(_pre)
        , wasmStore(pre->engine)
        , wasmCtx(wasmStore)
        , instance(unwrap(pre->instancePre.instantiate(wasmCtx)))
        , memory_(getExport<Memory>("memory"))
        , logPrefix(pre->name)
    {
        wasmCtx.set_data(this);
    }

    template<typename T>
    T getExport(std::string_view name)
    {
        auto ext = instance.get(wasmCtx, name);
        if (!ext)
            throw Error("Wasm module '%s' does not export '%s'", pre->name, name);
        auto res = std::get_if<T>(&*ext);
        if (!res)
            throw Error("export '%s' of Wasm module '%s' does not have the right type", name, pre->name);
        return *res;
    }

    std::vector<Val> runFunction(std::string_view name, const std::vector<Val> & args)
    {
        functionName = name;
        return unwrap(getExport<Func>(name).call(wasmCtx, args));
    }

    auto memory()
    {
        return memory_.data(wasmCtx);
    }

    std::monostate panic(uint32_t ptr, uint32_t len)
    {
        throw Error("Wasm panic: %s", Uncolored(span2string(memory().subspan(ptr, len))));
    }

    std::monostate warn(uint32_t ptr, uint32_t len)
    {
        doWarn(span2string(memory().subspan(ptr, len)));
        return {};
    }

    void doWarn(std::string_view s)
    {
        if (functionName)
            nix::warn("'%s' function '%s': %s", logPrefix, functionName.value_or("<unknown>"), s);
        else
            nix::warn("'%s': %s", logPrefix, s);
    }
};

template<typename R, typename... Args>
static void regFun(Linker & linker, std::string_view name, R (NixWasmInstance::*f)(Args...))
{
    unwrap(linker.func_wrap("env", name, [f](Caller caller, Args... args) -> Result<R, Trap> {
        try {
            auto instance = std::any_cast<NixWasmInstance *>(caller.context().get_data());
            return (*instance.*f)(args...);
        } catch (std::exception & e) {
            return Trap(e.what());
        } catch (...) {
            return Trap("unknown exception");
        }
    }));
}

static void regFuns(Linker & linker, bool useWasi)
{
    regFun(linker, "panic", &NixWasmInstance::panic);
    regFun(linker, "warn", &NixWasmInstance::warn);
}

template<typename T>
struct LazyMakeRef
{
    ref<T> p;

    template<typename... Args>
    LazyMakeRef(Args &&... args)
        : p(make_ref<T>(std::move(args...)))
    {
    }
};

/**
 * Callback for WASI stdout/stderr writes. It splits the output into lines and logs each line separately.
 */
struct WasiLogger
{
    NixWasmInstance & instance;

    std::string data;

    ~WasiLogger()
    {
        if (!data.empty())
            instance.doWarn(data);
    }

    void operator()(std::string_view s)
    {
        data.append(s);

        while (true) {
            auto pos = data.find('\n');
            if (pos == std::string_view::npos)
                break;
            instance.doWarn(data.substr(0, pos));
            data.erase(0, pos + 1);
        }
    }
};

static void builtinWasm(const BuiltinBuilderContext & ctx)
{
    auto wat = ctx.drv.env.at("wat");     // TODO: Check if defined
    auto outPath = ctx.outputs.at("out"); // TODO: Support multiple outputs

    try {
        auto instance = NixWasmInstance{make_ref<NixWasmInstancePre>(wat)};

        std::string functionName = "_start";

        debug("calling wasm module");

        // auto argId = instance.addValue(firstArg);

        WasiLogger wasiLogger{instance};

        auto loggerTrampoline = [](void * data, const unsigned char * buf, size_t len) -> ptrdiff_t {
            auto wasiLogger = static_cast<WasiLogger *>(data);
            auto str = std::string_view((const char *) buf, len);
            (*wasiLogger)(str);
            return len;
        };

        WasiConfig wasiConfig;
        wasi_config_set_stdout_custom(wasiConfig.capi(), loggerTrampoline, &wasiLogger, nullptr);
        wasi_config_set_stderr_custom(wasiConfig.capi(), loggerTrampoline, &wasiLogger, nullptr);
        std::string storePathStr = remove_last_path_element(outPath);
        debug("allowing access to path %s", storePathStr);
        const char * storePath = storePathStr.c_str();
        wasi_config_preopen_dir(
            wasiConfig.capi(),
            storePath,
            "/store",
            WASMTIME_WASI_DIR_PERMS_READ | WASMTIME_WASI_DIR_PERMS_WRITE,
            WASMTIME_WASI_FILE_PERMS_READ | WASMTIME_WASI_FILE_PERMS_WRITE);
        // TODO: Env vars
        // wasiConfig.argv({"wasi", std::to_string(argId)});
        unwrap(instance.wasmStore.context().set_wasi(std::move(wasiConfig)));

        auto outName = last_path_element(outPath);
        const uint8_t * bytes = reinterpret_cast<const uint8_t *>(outName.data());
        size_t len = outName.size();
        auto data = instance.memory();
        data[100] = len;
        uint32_t offset = 200;

        std::copy(bytes, bytes + len, data.begin() + offset);

        auto results = instance.getExport<Func>(functionName).call(instance.wasmCtx, {/* args go here */}).unwrap();
    } catch (Error & e) {
        // e.addTrace(state.positions[pos], "while building a Wasm module");
        throw;
    }
}

static RegisterBuiltinBuilder registerWasm("wasm", builtinWasm);

} // namespace nix
