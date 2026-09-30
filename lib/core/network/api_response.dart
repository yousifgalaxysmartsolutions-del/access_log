/// Unwrap according to each endpoint contract, not by guessing envelope keys.
class ApiResponse {
  const ApiResponse(this.data);
  final Map<String, dynamic> data;
  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(json);
  Map<String, dynamic> toJson() => data;
}
