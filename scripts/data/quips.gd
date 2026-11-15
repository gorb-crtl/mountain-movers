class_name Quips
extends RefCounted
## Things the boss says. Add more, the boss has a lot of opinions.

const INTRO: Array = [
	"See that mountain over there? I want it gone!",
]

const NEW_MOUNTAIN: Array = [
	"Great. Now see THAT mountain? Gone. By Friday.",
	"It grew back. Bigger. I don't want to talk about it.",
	"Legal says the mountain is 'self-replenishing'. I say it's insubordinate.",
	"New mountain. Same deadline.",
	"Who keeps PUTTING these here?",
]

const IDLE: Array = [
	"Is that mountain still there? Why is it still there?",
	"I'm not paying you to look at the mountain. I'm paying you to remove it.",
	"Faster. Think of the shareholders. I am the shareholders.",
	"When I was your age I moved mountains with a teaspoon.",
	"Keep going. I can still see it from my office window.",
	"Every pixel you move is a pixel I don't have to look at.",
	"Have you tried hitting it harder?",
	"Your performance review is in three pixels.",
	"I want that mountain flatter than my quarterly projections.",
]

const DYNAMITE: Array = [
	"BOOM! Now THAT'S synergy!",
	"Did you file the paperwork for that? Doesn't matter. Again!",
	"Ha! Love the smell of quarterly progress.",
]

const TRUCK: Array = [
	"Ka-ching! That's MY ka-ching.",
	"Another truckload! Keep 'em coming.",
	"Rocks to money. Alchemy, basically.",
]

const NUKE: Array = [
	"Was that... legal? Don't answer that.",
	"I said gone, not GONE gone. ...Actually, that works.",
	"My ears are ringing with PROFIT.",
]

const BIRD: Array = [
	"Is that bird on payroll?",
	"Good bird. Great bird. Employee of the month.",
]

const MILITARY: Array = [
	"I called in a few favours. Don't ask which country.",
	"More firepower! The mountain won't know what hit it.",
]

const ITEM: Array = [
	"A what? Sell it. Sell it immediately.",
	"Put it in the museum. The museum of SELLING IT.",
	"Ooh. Is it valuable? Then it's mine. I mean, the company's.",
]

const UPGRADE: Array = [
	"Spending money to make money. I like it.",
	"Is that a business expense? Everything's a business expense.",
	"New gear! Now dig twice as hard for the same pay.",
]

const CLEAR: Array = [
	"Huh. It's gone. ...I suppose that's adequate.",
	"Not bad! I'll mention you in my bonus speech. My bonus.",
	"Gone! Finally! Wait. What's that over there?",
]

const BAILOUT: Array = [
	"Giving up? Fine. It'll grow back. They always do.",
	"A strategic retreat. I'll allow it. Once. Maybe twice.",
]

const VICTORY: Array = [
	"The horizon... it's FLAT. I'm... I'm actually happy. Don't tell anyone.",
]


static func pick(list: Array) -> String:
	return list[randi() % list.size()]
