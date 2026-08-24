abstract final class AiProviderConfig {
  const AiProviderConfig._();

  static const baseUrl = 'https://api.groq.com/openai/v1';
  static const apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );
  static const model = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'qwen/qwen3.6-27b',
  );
  static const fallbackModel = 'llama-3.1-8b-instant';
  //static const fallbackModel = 'openai/gpt-oss-20b';
}
