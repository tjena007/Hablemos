import Foundation

/// One step on the path: the scenario Lucía plays, the words to warm up on, and how she opens.
public struct Lesson: Equatable, Sendable, Identifiable {
    public let scenario: ScenarioConfig
    public let warmup: Warmup
    public let opening: String

    public var id: String { scenario.id }
}

public struct CourseUnit: Equatable, Sendable, Identifiable {
    public let id: String
    public let number: Int
    public let title: String
    public let subtitle: String
    public let lessons: [Lesson]
}

/// The guided course, in order. A lesson is done once a conversation for it has been saved,
/// so progress needs no storage of its own and travels with the progress export.
public enum Course {
    public static var lessons: [Lesson] { units.flatMap(\.lessons) }

    /// A lesson counts as done once a saved conversation for it had at least this many learner turns.
    public static let turnsToComplete = 3

    public static func lesson(_ id: String) -> Lesson? {
        lessons.first { $0.id == id }
    }

    public static func unit(containing lessonID: String) -> CourseUnit? {
        units.first { $0.lessons.contains { $0.id == lessonID } }
    }

    /// The first lesson at this level not yet done, or nil once the level's lessons are finished.
    public static func nextLesson(completed: Set<String>, level: CEFRLevel) -> Lesson? {
        lessons.first { $0.scenario.level == level && !completed.contains($0.id) }
    }

    public static let units: [CourseUnit] = [
        CourseUnit(id: "u1", number: 1, title: "Greetings & names", subtitle: "Say hello, who you are and where you're from", lessons: [
            lesson("u1-hola", "Hola, ¿qué tal?", "Greet someone and say how you are",
                   role: "a friendly neighbour in Mexico City", description: "you bump into the learner on the street and say hello",
                   missions: ["Say hello", "Say how you are", "Ask how she is"],
                   opening: "¡Hola! ¿Qué tal?",
                   words: [("hola", "hello"), ("buenos días", "good morning"), ("bien", "well, fine"), ("gracias", "thank you")],
                   sentences: [("Hola, buenos días.", "Hello, good morning."), ("Bien, gracias. ¿Y tú?", "Fine, thanks. And you?"), ("Muy bien, gracias.", "Very well, thank you.")]),
            lesson("u1-nombre", "¿Cómo te llamas?", "Give your name and ask for theirs",
                   role: "a friendly new coworker", description: "you are meeting the learner for the first time at work",
                   missions: ["Say your name", "Ask her name", "Say nice to meet you"],
                   opening: "¡Hola! Me llamo Lucía. ¿Cómo te llamas?",
                   words: [("me llamo", "my name is"), ("¿cómo te llamas?", "what's your name?"), ("mucho gusto", "nice to meet you"), ("igualmente", "likewise")],
                   sentences: [("Me llamo Ana.", "My name is Ana."), ("¿Cómo te llamas?", "What's your name?"), ("Mucho gusto, Lucía.", "Nice to meet you, Lucía.")]),
            lesson("u1-origen", "¿De dónde eres?", "Say where you're from and where you live",
                   role: "a curious traveller at a hostel", description: "you are chatting with the learner in a hostel common room",
                   missions: ["Say where you're from", "Say where you live", "Ask where she's from"],
                   opening: "¡Hola! Yo soy de México. ¿Y tú, de dónde eres?",
                   words: [("soy de", "I'm from"), ("vivo en", "I live in"), ("¿de dónde eres?", "where are you from?"), ("también", "also, too")],
                   sentences: [("Soy de Canadá.", "I'm from Canada."), ("Vivo en Estados Unidos.", "I live in the United States."), ("¿Y tú, de dónde eres?", "And you, where are you from?")]),
            lesson("u1-roleplay", "Role-play · Meeting a classmate", "Put it together on the first day of class",
                   role: "a classmate on the first day of a Spanish class", description: "you sit next to the learner on the first day of class",
                   missions: ["Greet her and give your name", "Say where you're from", "Say goodbye"],
                   opening: "¡Hola! ¿Es tu primer día también?",
                   words: [("estudio español", "I study Spanish"), ("¿y tú?", "and you?"), ("hasta luego", "see you later"), ("nos vemos", "see you")],
                   sentences: [("Estudio español.", "I study Spanish."), ("Me llamo Ana, ¿y tú?", "My name is Ana, and you?"), ("Hasta luego, nos vemos.", "See you later.")]),
        ]),
        CourseUnit(id: "u2", number: 2, title: "At the café", subtitle: "Order, count to ten and pay", lessons: [
            lesson("u2-pedir", "Ordering a coffee", "Order a drink politely",
                   role: "a friendly waitress at a café in Mexico City", description: "the learner is ordering a drink at your café",
                   missions: ["Order a coffee", "Say how you want it", "Say thank you"],
                   opening: "¡Buenos días! ¿Qué le sirvo?",
                   words: [("quiero", "I want"), ("un café", "a coffee"), ("por favor", "please"), ("con leche", "with milk")],
                   sentences: [("Quiero un café, por favor.", "I want a coffee, please."), ("Un café con leche.", "A coffee with milk."), ("Muchas gracias.", "Thank you very much.")]),
            lesson("u2-numeros", "Numbers 1–10", "Order more than one and understand totals",
                   role: "a friendly waitress at a busy café", description: "the learner is ordering for a group of friends",
                   missions: ["Order two drinks", "Order three of something", "Repeat the total"],
                   opening: "¡Hola! ¿Cuántas personas son hoy?",
                   words: [("dos", "two"), ("tres", "three"), ("cinco", "five"), ("diez", "ten")],
                   sentences: [("Dos cafés, por favor.", "Two coffees, please."), ("Quiero tres galletas.", "I want three cookies."), ("Son diez pesos.", "That's ten pesos.")]),
            lesson("u2-precios", "Asking prices", "Ask what something costs and react",
                   role: "a fruit seller at a market in Puebla", description: "the learner is buying fruit at your market stall",
                   missions: ["Ask how much something costs", "Say it's expensive", "Ask if they take card"],
                   opening: "¡Pásele, pásele! Las naranjas están muy buenas hoy.",
                   words: [("¿cuánto cuesta?", "how much is it?"), ("cuesta", "it costs"), ("es muy caro", "it's very expensive"), ("¿aceptan tarjeta?", "do you take card?")],
                   sentences: [("¿Cuánto cuesta el jugo?", "How much is the juice?"), ("Es muy caro.", "It's very expensive."), ("¿Aceptan tarjeta?", "Do you take card?")]),
            lesson("u2-roleplay", "Role-play · Breakfast at a fonda", "Order breakfast, ask the price and pay",
                   role: "playing Doña Rosa, the waitress at a small family restaurant in Puebla", description: "the learner is having breakfast at your fonda",
                   missions: ["Order a drink and something to eat", "Ask how much it costs", "Ask for the bill and say thanks"],
                   opening: "¡Buenos días! ¿Qué le sirvo?",
                   words: [("la cuenta", "the bill"), ("en efectivo", "in cash"), ("pan dulce", "sweet bread"), ("muchas gracias", "thank you very much")],
                   sentences: [("Quiero un café y pan dulce.", "I want a coffee and sweet bread."), ("La cuenta, por favor.", "The bill, please."), ("Pago en efectivo.", "I'll pay in cash.")]),
        ]),
        CourseUnit(id: "u3", number: 3, title: "My family", subtitle: "Introduce family members, ages and looks", lessons: [
            lesson("u3-familia", "Who's who", "Name the people in your family",
                   role: "a friendly coworker asking about family", description: "you and the learner are chatting about your families over lunch",
                   missions: ["Say who is in your family", "Say a family member's name", "Ask about her family"],
                   opening: "¿Tienes hermanos? Yo tengo una hermana.",
                   words: [("mi mamá", "my mom"), ("mi papá", "my dad"), ("mi hermano", "my brother"), ("mi hermana", "my sister")],
                   sentences: [("Tengo un hermano.", "I have a brother."), ("Mi mamá se llama Ana.", "My mom's name is Ana."), ("¿Y tu familia?", "And your family?")]),
            lesson("u3-edades", "Ages", "Say how old people are",
                   role: "a chatty neighbour", description: "your neighbour, the learner, is telling you about their family",
                   missions: ["Say your age", "Say a family member's age", "Ask her age"],
                   opening: "¡Qué bonita familia! ¿Cuántos años tiene tu hermano?",
                   words: [("tengo", "I have"), ("años", "years (old)"), ("mayor", "older"), ("menor", "younger")],
                   sentences: [("Tengo veinte años.", "I'm twenty years old."), ("Mi hermano es mayor.", "My brother is older."), ("¿Cuántos años tienes?", "How old are you?")]),
            lesson("u3-describir", "Describing people", "Say what someone looks like and is like",
                   role: "a friend looking at photos with the learner", description: "the learner is describing people in their photos",
                   missions: ["Describe how someone looks", "Describe someone's personality", "Ask about someone in her photo"],
                   opening: "¿Quién es esta persona en la foto?",
                   words: [("es alto", "he's tall"), ("es simpática", "she's nice"), ("tiene el pelo negro", "has black hair"), ("divertido", "fun")],
                   sentences: [("Mi papá es alto.", "My dad is tall."), ("Mi hermana es muy simpática.", "My sister is very nice."), ("Tiene el pelo negro.", "He has black hair.")]),
            lesson("u3-roleplay", "Role-play · Family photos", "Show Lucía photos of your family",
                   role: "a curious friend looking at the learner's family photos", description: "the learner is showing you photos of their family on their phone",
                   missions: ["Introduce two family members", "Say how old one of them is", "Describe one person"],
                   opening: "¡A ver, enséñame fotos de tu familia!",
                   words: [("este es", "this is (he)"), ("esta es", "this is (she)"), ("se llama", "is called"), ("es muy", "is very")],
                   sentences: [("Esta es mi mamá.", "This is my mom."), ("Este es mi hermano, se llama Carlos.", "This is my brother, his name is Carlos."), ("Es muy divertido.", "He's very fun.")]),
        ]),
        CourseUnit(id: "u4", number: 4, title: "Finding places", subtitle: "Ask where things are and follow directions", lessons: [
            lesson("u4-donde", "Where is…?", "Ask where a place is",
                   role: "a helpful passer-by in Mexico City", description: "the learner stops you on the street to ask where places are",
                   missions: ["Ask where the bathroom is", "Ask where the station is", "Say thank you"],
                   opening: "¿Sí? ¿Te puedo ayudar?",
                   words: [("¿dónde está?", "where is?"), ("el baño", "the bathroom"), ("la estación", "the station"), ("el museo", "the museum")],
                   sentences: [("Perdón, ¿dónde está el baño?", "Excuse me, where is the bathroom?"), ("¿Dónde está la estación?", "Where is the station?"), ("Muchas gracias.", "Thank you very much.")]),
            lesson("u4-cerca", "Near & far", "Ask if a place is close",
                   role: "a hotel receptionist", description: "the learner asks you about places near the hotel",
                   missions: ["Ask if a place is near", "Ask if you can walk", "Repeat what she said"],
                   opening: "Buenas tardes. ¿En qué le puedo ayudar?",
                   words: [("cerca", "near"), ("lejos", "far"), ("aquí", "here"), ("caminando", "walking")],
                   sentences: [("¿Está cerca de aquí?", "Is it near here?"), ("Está lejos.", "It's far."), ("¿Puedo ir caminando?", "Can I walk there?")]),
            lesson("u4-direcciones", "Left, right, straight", "Understand and repeat directions",
                   role: "a friendly police officer", description: "the learner asks you how to get somewhere",
                   missions: ["Ask how to get there", "Repeat left or right", "Check you understood"],
                   opening: "Buenas tardes. ¿Adónde va?",
                   words: [("a la derecha", "to the right"), ("a la izquierda", "to the left"), ("todo recto", "straight ahead"), ("la esquina", "the corner")],
                   sentences: [("Gira a la derecha.", "Turn right."), ("Sigue todo recto.", "Keep going straight."), ("Está en la esquina.", "It's on the corner.")]),
            lesson("u4-roleplay", "Role-play · Lost in Coyoacán", "Find your way to the museum",
                   role: "a local in Coyoacán, Mexico City", description: "the learner is lost and looking for the Frida Kahlo museum",
                   missions: ["Ask where the museum is", "Ask if it's near", "Repeat the directions back"],
                   opening: "Hola, ¿estás buscando algo?",
                   words: [("estoy perdido", "I'm lost"), ("busco", "I'm looking for"), ("¿está cerca?", "is it near?"), ("entonces", "so, then")],
                   sentences: [("Perdón, estoy perdido.", "Excuse me, I'm lost."), ("Busco el museo.", "I'm looking for the museum."), ("Entonces, a la derecha y todo recto.", "So, right and then straight.")]),
        ]),
    ]

    private static func lesson(
        _ id: String, _ title: String, _ subtitle: String,
        role: String, description: String, missions: [String], opening: String,
        words: [(String, String)], sentences: [(String, String)]
    ) -> Lesson {
        Lesson(
            scenario: ScenarioConfig(id: id, title: title, subtitle: subtitle, level: .a1, description: description, role: role, missions: missions),
            warmup: Warmup(words: words.map { WarmupItem($0.0, $0.1) }, sentences: sentences.map { WarmupItem($0.0, $0.1) }),
            opening: opening
        )
    }
}
