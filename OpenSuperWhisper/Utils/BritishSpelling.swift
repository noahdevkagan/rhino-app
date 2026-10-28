import Foundation

/// US → British spelling for English transcripts: colour, organise, centre, travelled,
/// defence, grey. Parakeet, Whisper and the cleanup model all lean American, so a UK user got
/// "capitalize" next to "colour" seemingly at random (Steve, 2026-10-21). Runs when
/// `britishSpellingEnabled` is on.
///
/// A fixed word list, not suffix rules: "-ize" → "-ise" by rule would also turn "size",
/// "prize" and "seize" into nonsense, and "-or" → "-our" would hit "doctor" and "humorous"
/// (which keeps its "o" in British English too). Words with a US/UK split that depends on
/// meaning are left alone: program/programme, license/licence, practice/practise, check,
/// tire, meter.
///
/// A capitalized word in the middle of a sentence is taken for a name and kept ("Pearl
/// Harbor", "Lincoln Center", "World Health Organization"), and so are words in `keep` (the
/// user's dictionary).
enum BritishSpelling {

    /// `text` with US spellings replaced by British ones.
    static func apply(_ text: String, keep: Set<String> = []) -> String {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: "\\p{L}+") else { return text }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }

        var result = ""
        var cursor = 0
        for match in matches {
            let range = match.range
            let word = ns.substring(with: range)
            result += ns.substring(with: NSRange(location: cursor, length: range.location - cursor))
            cursor = range.location + range.length
            guard let british = table[word.lowercased()], !keep.contains(word),
                  !isLikelyName(word, at: range.location, in: ns) else {
                result += word
                continue
            }
            result += matchingCase(british, like: word)
        }
        result += ns.substring(from: cursor)
        return result
    }

    /// Capitalized but not at the start of the text, a line, or a sentence; or all caps.
    private static func isLikelyName(_ word: String, at location: Int, in ns: NSString) -> Bool {
        guard let first = word.first, first.isUppercase else { return false }
        if word.count > 1, word.allSatisfy({ $0.isUppercase }) { return true }
        // Walk back over spaces, quotes and brackets to the previous real character.
        var i = location - 1
        while i >= 0 {
            let c = Character(ns.substring(with: NSRange(location: i, length: 1)))
            if c.isNewline { return false }
            if c.isWhitespace || "\"'“‘([-–—*•".contains(c) { i -= 1; continue }
            return !".!?:…".contains(c) && !c.isNumber
        }
        return false
    }

    /// `british` with the capitalization of `original` ("Color" → "Colour").
    private static func matchingCase(_ british: String, like original: String) -> String {
        guard let first = original.first, first.isUppercase else { return british }
        return british.prefix(1).uppercased() + british.dropFirst()
    }

    // MARK: - Word list

    /// Lowercase US form → British form, built once from the lists below.
    static let table: [String: String] = {
        var t: [String: String] = [:]

        // -ize → -ise, with every inflection. Only verbs listed here change.
        for verb in izeVerbs {
            let stem = String(verb.dropLast(3)) // "organ" from "organize"
            for (us, uk) in [("ize", "ise"), ("izes", "ises"), ("ized", "ised"),
                             ("izing", "ising"), ("izer", "iser"), ("izers", "isers"),
                             ("ization", "isation"), ("izations", "isations")] {
                t[stem + us] = stem + uk
            }
        }
        // -yze → -yse.
        for verb in ["analyze", "paralyze", "catalyze", "breathalyze", "dialyze", "electrolyze"] {
            let stem = String(verb.dropLast(3))
            for (us, uk) in [("yze", "yse"), ("yzed", "ysed"), ("yzing", "ysing"),
                             ("yzer", "yser"), ("yzers", "ysers")] {
                t[stem + us] = stem + uk
            }
        }
        // "analyzes" is also the plural noun "analyses": the same spelling either way.
        t["analyzes"] = "analyses"

        // -or → -our, only with suffixes that keep the "u" in British English
        // ("humorous", "vigorous", "laborious", "honorary" don't).
        for stem in ourStems {
            let uk = String(stem.dropLast(2)) + "our"
            for suffix in ["", "s", "ed", "ing", "ings", "ful", "fully", "less", "able", "ably",
                           "ite", "ites", "itism", "hood", "hoods", "ly", "al", "ally", "er", "ers", "y"] {
                t[stem + suffix] = uk + suffix
            }
        }
        // A medical term, "humoral" in both.
        t["humoral"] = nil

        // -er → -re, plus the forms whose letters move ("centered" → "centred").
        for stem in ["center", "theater", "fiber", "caliber", "saber", "somber", "specter",
                     "liter", "centimeter", "millimeter", "kilometer", "luster", "meager",
                     "sepulcher", "reconnoiter"] {
            let uk = String(stem.dropLast(2)) + "re"
            t[stem] = uk
            t[stem + "s"] = uk + "s"
        }
        for (us, uk) in [("centered", "centred"), ("centering", "centring"),
                         ("centerpiece", "centrepiece"), ("centerpieces", "centrepieces"),
                         ("centerfold", "centrefold"), ("theatergoer", "theatregoer"),
                         ("fiberglass", "fibreglass"), ("lackluster", "lacklustre")] {
            t[us] = uk
        }

        // Doubled consonants and the rest: explicit pairs.
        for (us, uk) in otherPairs { t[us] = uk }
        return t
    }()

    /// Verbs whose British spelling is "-ise". Deliberately missing: size, prize, seize,
    /// capsize, resize (the same in both).
    private static let izeVerbs: [String] = [
        "accessorize", "actualize", "agonize", "alphabetize", "antagonize",
        "apologize", "authorize", "baptize", "brutalize", "burglarize", "canonize",
        "capitalize", "categorize", "cauterize", "centralize", "characterize", "civilize",
        "colonize", "commercialize", "compartmentalize", "computerize", "conceptualize",
        "contextualize", "criticize", "crystallize", "customize", "decentralize",
        "demonize", "demoralize", "deodorize", "desensitize", "destabilize", "digitize",
        "dramatize", "economize", "emphasize", "empathize", "energize", "epitomize",
        "equalize", "evangelize", "externalize", "familiarize", "fantasize", "fertilize",
        "finalize", "formalize", "fraternize", "galvanize", "generalize", "glamorize",
        "globalize", "harmonize", "homogenize", "hospitalize", "humanize", "hybridize",
        "hypnotize", "idealize", "immunize", "incentivize", "initialize", "institutionalize",
        "internalize", "italicize", "itemize", "jeopardize", "legalize", "legitimize",
        "lionize", "localize", "marginalize", "materialize", "maximize", "memorialize",
        "memorize", "mesmerize", "metabolize", "minimize", "mobilize", "modernize",
        "moisturize", "monetize", "monopolize", "moralize", "nationalize", "neutralize",
        "normalize", "optimize", "organize", "ostracize", "overemphasize", "oxidize",
        "pasteurize", "patronize", "penalize", "personalize", "plagiarize", "polarize",
        "popularize", "pressurize", "prioritize", "privatize", "publicize", "pulverize",
        "randomize", "rationalize", "realize", "recognize", "reorganize", "revitalize",
        "revolutionize", "romanticize", "sanitize", "scandalize", "scrutinize", "sensitize",
        "serialize", "socialize", "specialize", "stabilize", "standardize", "sterilize",
        "stigmatize", "strategize", "subsidize", "summarize", "symbolize", "sympathize",
        "synchronize", "synthesize", "systematize", "tantalize", "terrorize", "theorize",
        "tranquilize", "trivialize", "unionize", "urbanize", "utilize", "vandalize",
        "vaporize", "verbalize", "victimize", "visualize", "vocalize", "weaponize",
        "westernize",
    ]

    /// US "-or" words that are "-our" in British English. Not doctor, actor, error, mirror.
    private static let ourStems: [String] = [
        "arbor", "ardor", "armor", "behavior", "candor", "clamor", "color", "demeanor",
        "endeavor", "favor", "fervor", "flavor", "glamor", "harbor", "honor", "humor",
        "labor", "misbehavior", "neighbor", "odor", "parlor", "rancor", "rigor", "rumor",
        "savior", "savor", "splendor", "tumor", "valor", "vapor", "vigor", "discolor",
        "dishonor", "disfavor",
    ]

    private static let otherPairs: [(String, String)] = [
        // Doubled L before a suffix.
        ("traveled", "travelled"), ("traveling", "travelling"), ("traveler", "traveller"),
        ("travelers", "travellers"), ("canceled", "cancelled"), ("canceling", "cancelling"),
        ("labeled", "labelled"), ("labeling", "labelling"), ("modeled", "modelled"),
        ("modeling", "modelling"), ("signaled", "signalled"), ("signaling", "signalling"),
        ("fueled", "fuelled"), ("fueling", "fuelling"), ("leveled", "levelled"),
        ("leveling", "levelling"), ("marveled", "marvelled"), ("marveling", "marvelling"),
        ("marvelous", "marvellous"), ("marvelously", "marvellously"),
        ("counselor", "counsellor"), ("counselors", "counsellors"),
        ("counseled", "counselled"), ("counseling", "counselling"),
        ("jeweler", "jeweller"), ("jewelers", "jewellers"), ("jewelry", "jewellery"),
        ("woolen", "woollen"), ("quarreled", "quarrelled"), ("quarreling", "quarrelling"),
        ("totaled", "totalled"), ("totaling", "totalling"), ("channeled", "channelled"),
        ("channeling", "channelling"), ("tunneled", "tunnelled"), ("tunneling", "tunnelling"),
        ("dueling", "duelling"), ("equaled", "equalled"), ("equaling", "equalling"),
        ("funneled", "funnelled"), ("funneling", "funnelling"), ("grueling", "gruelling"),
        ("libeled", "libelled"), ("panelist", "panellist"), ("panelists", "panellists"),
        ("penciled", "pencilled"), ("rivaled", "rivalled"), ("shoveled", "shovelled"),
        ("snorkeling", "snorkelling"), ("tasseled", "tasselled"), ("toweling", "towelling"),
        ("yodeling", "yodelling"), ("enrollment", "enrolment"), ("enrollments", "enrolments"),
        ("fulfill", "fulfil"), ("fulfills", "fulfils"), ("fulfillment", "fulfilment"),
        ("installment", "instalment"), ("installments", "instalments"),
        ("skillful", "skilful"), ("skillfully", "skilfully"), ("willful", "wilful"),
        ("willfully", "wilfully"),
        // -ense → -ence (nouns only in both).
        ("defense", "defence"), ("defenses", "defences"), ("offense", "offence"),
        ("offenses", "offences"), ("pretense", "pretence"), ("pretenses", "pretences"),
        // -og → -ogue.
        ("catalog", "catalogue"), ("catalogs", "catalogues"), ("cataloged", "catalogued"),
        ("cataloging", "cataloguing"), ("dialog", "dialogue"), ("dialogs", "dialogues"),
        ("monolog", "monologue"), ("prolog", "prologue"), ("epilog", "epilogue"),
        // ae / oe.
        ("anemia", "anaemia"), ("anemic", "anaemic"), ("anesthesia", "anaesthesia"),
        ("anesthetic", "anaesthetic"), ("anesthetist", "anaesthetist"),
        ("pediatric", "paediatric"), ("pediatrician", "paediatrician"),
        ("orthopedic", "orthopaedic"), ("hemorrhage", "haemorrhage"), ("leukemia", "leukaemia"),
        ("fetus", "foetus"), ("diarrhea", "diarrhoea"), ("maneuver", "manoeuvre"),
        ("maneuvers", "manoeuvres"), ("maneuvered", "manoeuvred"), ("maneuvering", "manoeuvring"),
        // Single words.
        ("gray", "grey"), ("grays", "greys"), ("grayish", "greyish"),
        ("mold", "mould"), ("molds", "moulds"), ("moldy", "mouldy"), ("molded", "moulded"),
        ("plow", "plough"), ("plows", "ploughs"), ("plowed", "ploughed"),
        ("cozy", "cosy"), ("coziness", "cosiness"), ("aluminum", "aluminium"),
        ("pajamas", "pyjamas"),
        ("mustache", "moustache"), ("mustaches", "moustaches"),
        ("skeptic", "sceptic"), ("skeptics", "sceptics"), ("skeptical", "sceptical"),
        ("skepticism", "scepticism"), ("aging", "ageing"), ("artifact", "artefact"),
        ("artifacts", "artefacts"), ("donut", "doughnut"), ("donuts", "doughnuts"),
        ("cozier", "cosier"), ("coziest", "cosiest"), ("sulfur", "sulphur"),
    ]

    // MARK: - Default

    /// On by default where the Mac's region writes British English. Explicit choices win.
    static var defaultEnabled: Bool {
        ["GB", "IE", "AU", "NZ", "ZA"].contains(Locale.current.region?.identifier ?? "")
    }
}
