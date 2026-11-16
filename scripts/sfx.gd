extends Node
## Sound effects, autoloaded as "Sfx". Plays files from res://assets/sounds/.
## Swap any .wav there for a real sound with the same name.

const POOL_SIZE := 24
## Don't let the same sound stack up more than this many times at once.
const MAX_SAME := 4

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _playing_name: Dictionary = {}   # player -> sound name
var _last_play: Dictionary = {}      # name -> time (ms)


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var dir := DirAccess.open("res://assets/sounds")
	if dir:
		for f in dir.get_files():
			# Exported builds list the .import files, not the .wav files.
			var file := f.trim_suffix(".import")
			if file.ends_with(".wav") and not _streams.has(file.get_basename()):
				_streams[file.get_basename()] = load("res://assets/sounds/" + file)


## pitch_jitter randomises pitch a little so repeated sounds don't grate.
func play(sound: String, volume_db := 0.0, pitch_jitter := 0.08, min_gap_ms := 30) -> void:
	if not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sound, -100000)) < min_gap_ms:
		return
	var same := 0
	var free_player: AudioStreamPlayer = null
	for p in _players:
		if p.playing:
			if _playing_name.get(p, "") == sound:
				same += 1
		elif free_player == null:
			free_player = p
	if same >= MAX_SAME or free_player == null:
		return
	_last_play[sound] = now
	_playing_name[free_player] = sound
	free_player.stream = _streams[sound]
	free_player.volume_db = volume_db + linear_to_db(maxf(Game.volume, 0.0001))
	free_player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	free_player.play()
