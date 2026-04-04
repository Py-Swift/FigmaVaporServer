// Shared CSS value enums used across multiple macros.

enum Spacing: String {
    case none, xs, sm, md, lg, xl

    var css: String {
        switch self {
        case .none: "gap-0"
        case .xs:   "gap-1"
        case .sm:   "gap-2"
        case .md:   "gap-4"
        case .lg:   "gap-6"
        case .xl:   "gap-8"
        }
    }
}

enum BorderRadius: String {
    case none, sm, md, lg, xl, full

    var css: String {
        switch self {
        case .none: "rounded-none"
        case .sm:   "rounded-sm"
        case .md:   "rounded-md"
        case .lg:   "rounded-lg"
        case .xl:   "rounded-xl"
        case .full: "rounded-full"
        }
    }
}

enum UIPadding: String {
    case none, xs, sm, md, lg, xl

    var css: String {
        switch self {
        case .none: "p-0"
        case .xs:   "p-1"
        case .sm:   "p-2"
        case .md:   "p-4"
        case .lg:   "p-6"
        case .xl:   "p-8"
        }
    }
}
