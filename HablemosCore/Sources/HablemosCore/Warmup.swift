import Foundation

public struct WarmupItem: Equatable, Sendable {
    public let spanish: String
    public let english: String

    public init(_ spanish: String, _ english: String) {
        self.spanish = spanish
        self.english = english
    }
}

/// Words to drill first, then short sentences that combine them, before the live conversation.
public struct Warmup: Equatable, Sendable {
    public let words: [WarmupItem]
    public let sentences: [WarmupItem]

    public var focusWords: [String] { words.map(\.spanish) }
    public var spokenTargets: [String] { (words + sentences).map(\.spanish) }

    public static func forScenario(_ id: String) -> Warmup {
        Course.lesson(id)?.warmup ?? table[id] ?? table["open"]!
    }

    private static let table: [String: Warmup] = [
        "cafe": Warmup(
            words: [WarmupItem("un café", "a coffee"), WarmupItem("un cruasán", "a croissant"), WarmupItem("quiero", "I want"), WarmupItem("por favor", "please")],
            sentences: [WarmupItem("Quiero un café, por favor.", "I want a coffee, please."), WarmupItem("Quiero un café y un cruasán.", "I want a coffee and a croissant."), WarmupItem("¿Cuánto es, por favor?", "How much is it, please?")]),
        "introductions": Warmup(
            words: [WarmupItem("me llamo", "my name is"), WarmupItem("vivo en", "I live in"), WarmupItem("trabajo", "I work"), WarmupItem("mucho gusto", "nice to meet you")],
            sentences: [WarmupItem("Me llamo Tanmay.", "My name is Tanmay."), WarmupItem("Vivo en Estados Unidos.", "I live in the United States."), WarmupItem("Trabajo con computadoras.", "I work with computers.")]),
        "directions": Warmup(
            words: [WarmupItem("a la derecha", "to the right"), WarmupItem("a la izquierda", "to the left"), WarmupItem("todo recto", "straight ahead"), WarmupItem("cerca", "near")],
            sentences: [WarmupItem("¿Dónde está la estación?", "Where is the station?"), WarmupItem("Gire a la derecha.", "Turn right."), WarmupItem("Está cerca de aquí.", "It is near here.")]),
        "shopping": Warmup(
            words: [WarmupItem("cuánto cuesta", "how much does it cost"), WarmupItem("la talla", "the size"), WarmupItem("más barato", "cheaper"), WarmupItem("me lo llevo", "I'll take it")],
            sentences: [WarmupItem("¿Cuánto cuesta esta camisa?", "How much does this shirt cost?"), WarmupItem("¿Tiene una talla más grande?", "Do you have a bigger size?"), WarmupItem("Me lo llevo, gracias.", "I'll take it, thanks.")]),
        "weekend": Warmup(
            words: [WarmupItem("fui", "I went"), WarmupItem("comí", "I ate"), WarmupItem("vi", "I saw / watched"), WarmupItem("con mis amigos", "with my friends")],
            sentences: [WarmupItem("El sábado fui al parque.", "On Saturday I went to the park."), WarmupItem("Comí con mis amigos.", "I ate with my friends."), WarmupItem("Vi una película.", "I watched a movie.")]),
        "story": Warmup(
            words: [WarmupItem("de repente", "suddenly"), WarmupItem("mientras", "while"), WarmupItem("al final", "in the end"), WarmupItem("me di cuenta", "I realized")],
            sentences: [WarmupItem("De repente empezó a llover.", "Suddenly it started to rain."), WarmupItem("Mientras caminaba, vi a un amigo.", "While I was walking, I saw a friend."), WarmupItem("Al final me di cuenta del error.", "In the end I realized the mistake.")]),
        "job": Warmup(
            words: [WarmupItem("el equipo", "the team"), WarmupItem("el proyecto", "the project"), WarmupItem("la reunión", "the meeting"), WarmupItem("me encanta", "I love")],
            sentences: [WarmupItem("Trabajo en un equipo pequeño.", "I work on a small team."), WarmupItem("Tengo una reunión mañana.", "I have a meeting tomorrow."), WarmupItem("Me encanta mi proyecto.", "I love my project.")]),
        "plans": Warmup(
            words: [WarmupItem("quedamos", "let's meet"), WarmupItem("el viernes", "on Friday"), WarmupItem("tengo ganas de", "I feel like"), WarmupItem("podemos", "we can")],
            sentences: [WarmupItem("¿Quedamos el viernes?", "Shall we meet on Friday?"), WarmupItem("Tengo ganas de ir al cine.", "I feel like going to the movies."), WarmupItem("Podemos cenar juntos.", "We can have dinner together.")]),
        "open": Warmup(
            words: [WarmupItem("creo que", "I think that"), WarmupItem("depende", "it depends"), WarmupItem("por ejemplo", "for example"), WarmupItem("sin embargo", "however")],
            sentences: [WarmupItem("Creo que es una buena idea.", "I think it is a good idea."), WarmupItem("Depende del día.", "It depends on the day."), WarmupItem("Por ejemplo, me gusta viajar.", "For example, I like to travel.")]),
        "opinions": Warmup(
            words: [WarmupItem("en mi opinión", "in my opinion"), WarmupItem("estoy de acuerdo", "I agree"), WarmupItem("no estoy seguro", "I'm not sure"), WarmupItem("por un lado", "on one hand")],
            sentences: [WarmupItem("En mi opinión, tienes razón.", "In my opinion, you're right."), WarmupItem("No estoy seguro de eso.", "I'm not sure about that."), WarmupItem("Por un lado, es más barato.", "On one hand, it's cheaper.")]),
    ]
}
