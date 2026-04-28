class OtpVerificationArgs {
  final String identifier; // Can be email or phone number
  final bool isEmail; // True if identifier is email, false if phone number

  OtpVerificationArgs({required this.identifier, required this.isEmail});
}