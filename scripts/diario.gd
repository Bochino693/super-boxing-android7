class_name Diario
extends Reference

## O DIÁRIO DA INICIALIZAÇÃO.
##
## Cada etapa da abertura do jogo (carregar, montar, aquecer, acordar a
## câmera, pedir permissão, abrir o Arduino) é gravada NA HORA num arquivo
## pequeno. Se a TV Box travar numa delas, o arquivo fica parado ali — e na
## próxima vez que o jogo abre ele sabe, e mostra, em que etapa parou.
## Sem cabo, sem computador, sem adivinhar.

const ARQUIVO = "user://diario_inicializacao.txt"
const FIM = "PRONTO"

## Estado compartilhado (as `static var` do Godot 4): um `const` com
## dicionário é único para a classe e pode ser alterado.
const _E = {
	"_inicio_ms": 0,
	"_travou_em": "",
	"_aberto": false,
	"_pronto": false,
}

## Começa um diário novo, lendo antes o da vez anterior.
static func inicio() -> void:
	if _E._aberto:
		return
	_E._aberto = true
	_E._inicio_ms = Time.get_ticks_msec()
	if Compat.existe(ARQUIVO):
		var velho = Compat.abrir(ARQUIVO, File.READ)
		if velho != null:
			var ultima = ""
			while not velho.eof_reached():
				var linha = velho.get_line().strip_edges()
				if not linha.empty():
					ultima = linha
			velho.close()
			if not ultima.empty() and not ultima.ends_with(FIM):
				_E._travou_em = ultima
	var novo = Compat.abrir(ARQUIVO, File.WRITE)
	if novo != null:
		novo.store_line("0.0s INICIO")
		novo.close()

## Grava uma etapa (com o tempo desde o início).
static func marca(etapa: String) -> void:
	if not _E._aberto or _E._pronto:
		return
	# Também no logcat (etiqueta "godot"), para ver a etapa pelo cabo USB.
	print("SUPERBOXING %.1fs %s" % [float(Time.get_ticks_msec() - _E._inicio_ms) / 1000.0, etapa])
	var f = Compat.abrir(ARQUIVO, File.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%.1fs %s" % [float(Time.get_ticks_msec() - _E._inicio_ms) / 1000.0, etapa])
	f.close()

## A inicialização terminou inteira: daqui em diante não se grava mais.
static func pronto() -> void:
	marca(FIM)
	_E._pronto = true

## Onde a inicialização ANTERIOR parou, se ela não chegou ao fim.
static func travou_em() -> String:
	return _E._travou_em
