import 'package:ente_auth/models/code.dart';

class SearchLogic {
  /// Filters the list of [codes] based on the [query] and [selectedTag].
  ///
  /// The filtering logic prioritizes:
  /// 1. Issuer match
  /// 2. Account match
  /// 3. Note match
  ///
  /// Returns a list of filtered codes sorted by match relevance.
  static List<Code> filter(
    List<Code> codes,
    String query, {
    String selectedTag = "",
    bool isTrashOpen = false,
  }) {
    if (query.isEmpty) {
      return codes
          .where(
            (element) =>
                !element.hasError &&
                (element.isTrashed == isTrashOpen) &&
                (selectedTag == "" ||
                    element.display.tags.contains(selectedTag)),
          )
          .toList();
    }

    final String val = query.toLowerCase();
    final List<Code> issuerMatch = [];
    final List<Code> accountMatch = [];
    final List<Code> noteMatch = [];

    for (final Code codeState in codes) {
      if (codeState.hasError ||
          (selectedTag != "" &&
              !codeState.display.tags.contains(selectedTag)) ||
          (codeState.isTrashed != isTrashOpen)) {
        continue;
      }

      if (codeState.issuer.toLowerCase().contains(val)) {
        issuerMatch.add(codeState);
      } else if (codeState.account.toLowerCase().contains(val)) {
        accountMatch.add(codeState);
      } else if (codeState.note.toLowerCase().contains(val)) {
        noteMatch.add(codeState);
      }
    }

    final List<Code> filteredCodes = [];
    filteredCodes.addAll(issuerMatch);
    filteredCodes.addAll(accountMatch);
    filteredCodes.addAll(noteMatch);

    return filteredCodes;
  }
}
