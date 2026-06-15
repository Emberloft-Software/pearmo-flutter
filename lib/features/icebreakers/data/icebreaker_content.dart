/// Static content for the ice-breaker mini-games. Keeping these as simple
/// client-side lists keeps the games working with nothing more than the
/// flexible `state` JSON column on `ice_breaker_sessions`.
class IcebreakerContent {
  IcebreakerContent._();

  /// "Would You Rather" prompts, cycled through by `state['round']`.
  static const List<(String, String)> wouldYouRatherPrompts = [
    ('Spend a weekend hiking in the mountains', 'Spend a weekend relaxing on a beach'),
    ('Always be 10 minutes early', 'Always be fashionably late'),
    ('Have a home-cooked meal every night', 'Try a new restaurant every week'),
    ('Travel to 10 new countries', 'Master a new skill or hobby'),
    ('Text throughout the day', 'Have one long call in the evening'),
    ('Plan every detail of a trip', 'Wing it and see what happens'),
    ('Be great at giving advice', 'Be great at listening'),
    ('Live in a bustling city', 'Live in a quiet countryside town'),
    ('Wake up early to watch the sunrise', 'Stay up late to watch the stars'),
    ('Have a big group of friends', 'Have a few very close friends'),
    ('Binge-watch a series in one night', 'Read a book over a week'),
    ('Cook together at home', 'Order takeout and watch a movie'),
    ('Take a spontaneous road trip', 'Plan a relaxing staycation'),
    ('Be unbeatable at trivia', 'Be unbeatable at karaoke'),
    ('Get a surprise gift', 'Get a handwritten letter'),
  ];

  /// "20 Questions" prompt bank — players take turns picking one of these
  /// (or typing their own) to ask the other person.
  static const List<String> twentyQuestionsPrompts = [
    "What's a small thing that instantly makes your day better?",
    'What does your ideal weekend look like?',
    "What's something you're really proud of?",
    'What kind of music do you put on when no one is watching?',
    "What's a place you'd love to visit someday?",
    'Are you more of a planner or a go-with-the-flow person?',
    "What's your favourite way to unwind after a long day?",
    'What did you want to be when you were a kid?',
    "What's a skill you'd like to learn?",
    'How do you usually spend a Sunday morning?',
    "What's something that always makes you laugh?",
    'Do you prefer mornings or late nights?',
    "What's a movie or show you could rewatch forever?",
    "What's your love language?",
    "What's one thing on your bucket list?",
    'Coffee or tea — and how do you take it?',
    "What's a tradition from your family you'd like to keep?",
    'How do you like to celebrate good news?',
    "What's something you're looking forward to right now?",
    'Cats, dogs, both, or neither?',
  ];

  /// Fixed stroke colors so each participant's drawing is distinguishable.
  static const String colorA = '#FF8C6B';
  static const String colorB = '#5FBFB3';
}
