import AVFoundation

/// Short interface sounds. They use the "ambient" audio session: they mix with the user's music
/// instead of stopping it, and stay quiet in Silent Mode.
/// Turned off with Settings > Sound effects.
@MainActor
enum SoundEffects {
    enum Sound: String {
        /// A book sliding off the shelf (Resources/Sounds; made by design/sounds/make-book-sound.mjs).
        case bookPull = "book-pull"
    }

    private static var players: [Sound: AVAudioPlayer] = [:]
    private static var isSessionReady = false

    static func play(_ sound: Sound) {
        guard Prefs.soundEffectsEnabled else { return }
        prepareSession()
        guard let player = player(for: sound) else { return }
        player.currentTime = 0
        player.play()
    }

    /// Loads the sound ahead of time, so the first tap plays without a delay.
    static func preload(_ sound: Sound) {
        _ = player(for: sound)
    }

    private static func player(for sound: Sound) -> AVAudioPlayer? {
        if let player = players[sound] { return player }
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = 0.7
        player.prepareToPlay()
        players[sound] = player
        return player
    }

    private static func prepareSession() {
        guard !isSessionReady else { return }
        isSessionReady = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }
}
