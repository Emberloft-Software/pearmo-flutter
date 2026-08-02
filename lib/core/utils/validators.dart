/// Lightweight form validators shared across auth, onboarding and settings
/// screens. Keep these pure functions so they're trivial to unit test.
class Validators {
  Validators._();

  /// Requires E.164 format (e.g. +94771234567) as used by Supabase phone
  /// auth and the SMS OTP flow.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your phone number';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(trimmed)) {
      return 'Enter a valid phone number with country code, e.g. +94771234567';
    }
    return null;
  }

  /// Collapses every way a Sri Lankan user might type their mobile number
  /// into the single E.164 string Supabase phone auth expects.
  ///
  /// This matters more than it looks: Supabase Auth keys accounts by the
  /// exact phone string it receives, so the local and international forms
  /// of one number would mint two separate identities for the same person.
  /// That has already happened in this project (see CLAUDE.md) — the old
  /// validator accepted any syntactically valid E.164 string, and a bare
  /// Sri Lankan mobile without its country code parses as a perfectly
  /// legitimate foreign number.
  ///
  ///   0771234567      -> +94771234567   (local format, 10 digits)
  ///   771234567       -> +94771234567   (9 digits, no trunk prefix)
  ///   94771234567     -> +94771234567   (country code, no plus)
  ///   +94 77 123 4567 -> +94771234567   (spaces/punctuation ignored)
  ///
  /// Returns null if the input isn't a Sri Lankan mobile number.
  static String? normalizeSriLankanMobile(String? value) {
    if (value == null) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Exactly three accepted shapes, each matched on length AND prefix
    // together. Deliberately not "strip a prefix then validate": that
    // approach lets a malformed input fall through the wrong branch and
    // still come out looking plausible. Every SMS we send costs money, so
    // anything ambiguous is rejected here rather than handed to the OTP
    // provider.
    final String local;
    if (digits.length == 9 && digits.startsWith('7')) {
      local = digits; //            771234567
    } else if (digits.length == 10 && digits.startsWith('07')) {
      local = digits.substring(1); //  0771234567
    } else if (digits.length == 11 && digits.startsWith('947')) {
      local = digits.substring(2); //   94771234567
    } else {
      return null;
    }

    // Every Sri Lankan mobile prefix is 07x, so the subscriber number is
    // always 9 digits starting with 7. Landlines (011, 081, ...) are
    // rejected deliberately — they can't receive an SMS OTP, so accepting
    // one would burn a message and drop the user on a code screen that
    // never fills in.
    //
    // Not narrowing further to the specific allocated prefixes (070-072,
    // 074-078): blocking a prefix that is valid, or becomes valid later,
    // locks real users out entirely — a worse failure than the handful of
    // wasted messages it would save.
    if (!RegExp(r'^7\d{8}$').hasMatch(local)) return null;
    return '+94$local';
  }

  /// Login field validator. Sri Lanka only for now — the app is
  /// Sri-Lanka-shaped throughout (`country_code` defaults to `LK`,
  /// `RegionsData` is provinces, `score_compatibility` matches location by
  /// exact country string), so a foreign number has no working experience
  /// behind it. Widening later means relaxing this one function.
  static String? sriLankanMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your mobile number';
    }
    if (normalizeSriLankanMobile(value) == null) {
      return 'Enter a Sri Lankan mobile number, e.g. 0771234567';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter the code you received';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'The code should be 6 digits';
    }
    return null;
  }

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String label = 'This field'}) {
    if (value != null && value.length > max) {
      return '$label must be $max characters or fewer';
    }
    return null;
  }

  /// Onboarding requires users to be 18+.
  static String? dateOfBirthAdult(DateTime? dob) {
    if (dob == null) {
      return 'Select your date of birth';
    }
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    if (age < 18) {
      return 'You must be 18 or older to use Pearmo';
    }
    if (age > 100) {
      return 'Please enter a valid date of birth';
    }
    return null;
  }

  /// E.164 phone validation for the emergency contact on date check-ins.
  static String? emergencyContact(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter an emergency contact number';
    }
    return phone(value);
  }
}
