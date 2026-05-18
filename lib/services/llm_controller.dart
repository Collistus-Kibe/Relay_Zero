import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:geolocator/geolocator.dart';
import '../models/triage_payload.dart';

// ----------------------------------------------------------------------
// 1. llama.cpp FFI Type Definitions
// ----------------------------------------------------------------------

final class LlamaModel extends ffi.Opaque {}
final class LlamaContext extends ffi.Opaque {}

// Define the struct for LlamaModelParams (pass-by-value in C)
final class LlamaModelParams extends ffi.Struct {
  @ffi.Int32() external int n_gpu_layers;
  @ffi.Int32() external int split_mode;
  @ffi.Int32() external int main_gpu;
  external ffi.Pointer<ffi.Float> tensor_split;
  // Use padding to account for remaining fields in the C struct across versions
  @ffi.Array(1024) external ffi.Array<ffi.Uint8> _padding;
}

// Define the struct for LlamaContextParams (pass-by-value in C)
final class LlamaContextParams extends ffi.Struct {
  @ffi.Uint32() external int seed;
  @ffi.Uint32() external int n_ctx;
  @ffi.Uint32() external int n_batch;
  @ffi.Uint32() external int n_threads;
  @ffi.Uint32() external int n_threads_batch;
  @ffi.Array(1024) external ffi.Array<ffi.Uint8> _padding;
}

// Function signatures
typedef llama_backend_init_func = ffi.Void Function();
typedef LlamaBackendInit = void Function();

typedef llama_backend_free_func = ffi.Void Function();
typedef LlamaBackendFree = void Function();

typedef llama_model_default_params_func = LlamaModelParams Function();
typedef LlamaModelDefaultParams = LlamaModelParams Function();

typedef llama_context_default_params_func = LlamaContextParams Function();
typedef LlamaContextDefaultParams = LlamaContextParams Function();

typedef llama_load_model_from_file_func = ffi.Pointer<LlamaModel> Function(ffi.Pointer<Utf8>, LlamaModelParams);
typedef LlamaLoadModelFromFile = ffi.Pointer<LlamaModel> Function(ffi.Pointer<Utf8>, LlamaModelParams);

typedef llama_new_context_with_model_func = ffi.Pointer<LlamaContext> Function(ffi.Pointer<LlamaModel>, LlamaContextParams);
typedef LlamaNewContextWithModel = ffi.Pointer<LlamaContext> Function(ffi.Pointer<LlamaModel>, LlamaContextParams);

typedef llama_free_model_func = ffi.Void Function(ffi.Pointer<LlamaModel>);
typedef LlamaFreeModel = void Function(ffi.Pointer<LlamaModel>);

typedef llama_free_func = ffi.Void Function(ffi.Pointer<LlamaContext>);
typedef LlamaFree = void Function(ffi.Pointer<LlamaContext>);

// Inference/Generation signatures (abbreviated for grammar/sampling)
// In production, grammar is parsed via C++ extensions or `llama_grammar_init`.
typedef llama_generate_json_func = ffi.Pointer<Utf8> Function(
  ffi.Pointer<LlamaContext>, 
  ffi.Pointer<Utf8> prompt, 
  ffi.Pointer<Utf8> grammar
);
typedef LlamaGenerateJson = ffi.Pointer<Utf8> Function(
  ffi.Pointer<LlamaContext>, 
  ffi.Pointer<Utf8> prompt, 
  ffi.Pointer<Utf8> grammar
);


// ----------------------------------------------------------------------
// 2. LLM Controller (Compute Gate)
// ----------------------------------------------------------------------
class LLMController {
  late final ffi.DynamicLibrary _llamaLib;
  
  // Bound functions
  late final LlamaBackendInit _backendInit;
  late final LlamaBackendFree _backendFree;
  late final LlamaModelDefaultParams _modelDefaultParams;
  late final LlamaContextDefaultParams _contextDefaultParams;
  late final LlamaLoadModelFromFile _loadModelFromFile;
  late final LlamaNewContextWithModel _newContextWithModel;
  late final LlamaFreeModel _freeModel;
  late final LlamaFree _freeContext;
  late final LlamaGenerateJson _generateJson;

  // Hardcoded absolute path for the Kaggle Hackathon device environment
  final String _modelPath = "/storage/emulated/0/Download/gemma-4-2b-it-Q4_K_M.gguf";
  
  final String _triageGrammar = r'''
    root ::= "{" ws "\"t\"" ws ":" ws "\"" triage "\"" ws "," ws "\"h\"" ws ":" ws "\"" string "\"" ws "," ws "\"m\"" ws ":" ws boolean ws "," ws "\"c\"" ws ":" ws number ws "}"
    triage ::= "R" | "Y" | "G"
    boolean ::= "true" | "false"
    string ::= [a-zA-Z]+
    number ::= [0-9]+
    ws ::= [ \t\n]*
  ''';

  bool _isInitialized = false;

  LLMController() {
    _initFfiBindings();
  }

  void _initFfiBindings() {
    try {
      // Load library specific to the platform
      _llamaLib = Platform.isAndroid 
          ? ffi.DynamicLibrary.open('libllama.so') 
          : Platform.isIOS 
              ? ffi.DynamicLibrary.process()
              : ffi.DynamicLibrary.open('llama.dll');
    } catch (e) {
      print("CRITICAL: Failed to load llama native library. AI Inference will not work: $e");
      return;
    }

    // Bind all functions
    _backendInit = _llamaLib.lookup<ffi.NativeFunction<llama_backend_init_func>>('llama_backend_init').asFunction();
    _backendFree = _llamaLib.lookup<ffi.NativeFunction<llama_backend_free_func>>('llama_backend_free').asFunction();
    _modelDefaultParams = _llamaLib.lookup<ffi.NativeFunction<llama_model_default_params_func>>('llama_model_default_params').asFunction();
    _contextDefaultParams = _llamaLib.lookup<ffi.NativeFunction<llama_context_default_params_func>>('llama_context_default_params').asFunction();
    _loadModelFromFile = _llamaLib.lookup<ffi.NativeFunction<llama_load_model_from_file_func>>('llama_load_model_from_file').asFunction();
    _newContextWithModel = _llamaLib.lookup<ffi.NativeFunction<llama_new_context_with_model_func>>('llama_new_context_with_model').asFunction();
    _freeModel = _llamaLib.lookup<ffi.NativeFunction<llama_free_model_func>>('llama_free_model').asFunction();
    _freeContext = _llamaLib.lookup<ffi.NativeFunction<llama_free_func>>('llama_free').asFunction();
    
    // Assumes a custom wrapper or helper exposed in the shared lib for single-shot generation
    _generateJson = _llamaLib.lookup<ffi.NativeFunction<llama_generate_json_func>>('llama_generate_json_with_grammar').asFunction();
    _isInitialized = true;
  }

  /// Processes the SOS through the local quantized model. 
  /// STRICT COMPUTE GATE: Model loaded -> Inference -> Model Free.
  Future<TriagePayload?> processSOS(String rawText) async {
    // 1. Fetch GPS Coordinates
    Position? position;
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Mock coordinates for desktop emulator showcase
        position = Position(
          longitude: 36.960, latitude: -1.148, 
          timestamp: DateTime.now(), accuracy: 1, 
          altitude: 0, heading: 0, speed: 0, speedAccuracy: 0,
          altitudeAccuracy: 0, headingAccuracy: 0
        );
      } else {
        // Fast timeout since it's an emergency
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, 
          timeLimit: const Duration(seconds: 3)
        );
      }
    } catch (e) {
      print("GPS Fetch Failed: \$e");
    }

    if (!_isInitialized) {
      print("LLM Error: Native library not initialized.");
      return null;
    }

    ffi.Pointer<LlamaModel> model = ffi.nullptr;
    ffi.Pointer<LlamaContext> context = ffi.nullptr;

    try {
      print("LLM: [GATE OPEN] Initializing backend and loading model into RAM...");
      _backendInit();

      // Get default params
      LlamaModelParams modelParams = _modelDefaultParams();
      modelParams.n_gpu_layers = 99; // Offload fully to device GPU if supported

      LlamaContextParams ctxParams = _contextDefaultParams();
      ctxParams.n_ctx = 1024;
      ctxParams.n_threads = 4;

      // Pass the local file path to the C API
      final ffi.Pointer<Utf8> cModelPath = _modelPath.toNativeUtf8();
      model = _loadModelFromFile(cModelPath, modelParams);
      calloc.free(cModelPath);

      if (model == ffi.nullptr) {
        throw Exception("Failed to load model from $_modelPath");
      }

      // Create context
      context = _newContextWithModel(model, ctxParams);
      if (context == ffi.nullptr) {
        throw Exception("Failed to create model context.");
      }

      // Build Prompt and Grammar Strings
      final String fullPrompt = "Extract emergency data:\nInput: $rawText\nOutput:";
      final ffi.Pointer<Utf8> cPrompt = fullPrompt.toNativeUtf8();
      final ffi.Pointer<Utf8> cGrammar = _triageGrammar.toNativeUtf8();

      print("LLM: Running constrained inference...");
      // In production, this call blocks the thread. Run in an isolate to keep UI smooth.
      final ffi.Pointer<Utf8> cResponse = _generateJson(context, cPrompt, cGrammar);
      
      final String jsonResponse = cResponse.toDartString();
      
      calloc.free(cPrompt);
      calloc.free(cGrammar);
      // NOTE: cResponse memory lifecycle depends on the C implementation (must be freed if allocated)

      print("LLM: Inference complete. Result: \$jsonResponse");
      
      final Map<String, dynamic> decoded = jsonDecode(jsonResponse);
      return TriagePayload(
        triageLevel: decoded['t'] as String,
        primaryHazard: decoded['h'] as String,
        medicalFlag: decoded['m'] as bool,
        headcount: decoded['c'] as int,
        lat: position?.latitude,
        lng: position?.longitude,
      );

    } catch (e) {
      print("LLM Error: $e");
      return null;
    } finally {
      // THE COMPUTE GATE CLOSES: Strict RAM Purge
      print("LLM: [GATE CLOSE] Aggressively freeing context and model from RAM.");
      if (context != ffi.nullptr) _freeContext(context);
      if (model != ffi.nullptr) _freeModel(model);
      _backendFree();
    }
  }

  /// Direct LLM query for the Offline Survival Intelligence Mode.
  Future<String> querySurvivalGuide(String prompt) async {
    if (!_isInitialized) {
      return "ERROR: Survival Engine Offline. Native dependencies missing.";
    }

    ffi.Pointer<LlamaModel> model = ffi.nullptr;
    ffi.Pointer<LlamaContext> context = ffi.nullptr;

    try {
      _backendInit();
      LlamaModelParams modelParams = _modelDefaultParams();
      modelParams.n_gpu_layers = 99; 

      LlamaContextParams ctxParams = _contextDefaultParams();
      ctxParams.n_ctx = 2048;
      ctxParams.n_threads = 4;

      final ffi.Pointer<Utf8> cModelPath = _modelPath.toNativeUtf8();
      model = _loadModelFromFile(cModelPath, modelParams);
      calloc.free(cModelPath);

      if (model == ffi.nullptr) throw Exception("Failed to load model");

      context = _newContextWithModel(model, ctxParams);
      if (context == ffi.nullptr) throw Exception("Failed to create context");

      final String fullPrompt = "You are an offline survival expert. Give brief, step-by-step medical or survival advice based on the user prompt.\nUser: \$prompt\nExpert:";
      final ffi.Pointer<Utf8> cPrompt = fullPrompt.toNativeUtf8();
      
      // We pass a null grammar for freeform text generation
      final ffi.Pointer<Utf8> cResponse = _generateJson(context, cPrompt, ffi.nullptr);
      final String response = cResponse.toDartString();
      
      calloc.free(cPrompt);
      return response.trim();
    } catch (e) {
      print("Survival Guide LLM Error: \$e");
      return "Error generating survival advice.";
    } finally {
      if (context != ffi.nullptr) _freeContext(context);
      if (model != ffi.nullptr) _freeModel(model);
      _backendFree();
    }
  }
}
