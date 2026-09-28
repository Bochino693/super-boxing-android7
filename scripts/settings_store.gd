class_name SettingsStore
extends Reference

## Persistência em user:// com gravação segura: escreve num arquivo
## temporário e só então renomeia por cima do oficial. Se a máquina
## desligar no meio da escrita, o arquivo antigo continua intacto.

const PATH = "user://punch_challenge_settings.json"
const PATH_TMP = "user://punch_challenge_settings.tmp"
## Este próprio arquivo: a linha de trabalho chama `_gravar` nele.
const CAMINHO_DO_SCRIPT = "res://scripts/settings_store.gd"

static func load_data() -> Dictionary:
	if not Compat.existe(PATH):
		return {}
	var file = Compat.abrir(PATH, File.READ)
	if file == null:
		return {}
	var parsed = parse_json(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

## ======================================================================
## GRAVAR NÃO PODE ACONTECER NO QUADRO DO PLACAR.
##
## `_fechar_rodada()` fecha o ranking, atualiza a estatística e GRAVA O
## ARQUIVO — tudo no mesmo quadro em que o número começa a subir na tela.
## Num PC com SSD isso passa despercebido. Na memória eMMC de um TV box,
## abrir, escrever e renomear são três chamadas de sistema que levam
## milissegundos de verdade, e elas caem exatamente no instante em que a
## tela mais precisa ser instantânea. É a descrição de "trava quando gera
## a pontuação".
##
## A montagem do texto continua na linha do jogo, e é de propósito: ela é
## barata (vinte linhas de ranking) e é o que congela o estado NAQUELE
## instante. O que vai para a linha de trabalho é só o disco.
##
## UMA GRAVAÇÃO PENDENTE DE CADA VEZ, e a última vence: um arquivo de
## ajustes não tem histórico, tem estado atual. Se três gravações forem
## pedidas enquanto uma está no ar, duas seriam escrita jogada fora — e
## disco desperdiçado é bateria e vida útil desperdiçadas num aparelho
## que fica ligado o dia inteiro.
## Estado compartilhado (as `static var` do Godot 4): um `const` com
## dicionário é único para a classe e pode ser alterado.
const _E = {
	"_tarefa": null,
	"_pendente": "",
}

static func save_data_async(data: Dictionary) -> void:
	_E._pendente = JSON.print(data, "\t")
	_bombear()

static func _bombear() -> void:
	if _E._pendente.empty():
		return
	if _E._tarefa != null:
		if not Compat.terminou(_E._tarefa):
			return
		Compat.esperar(_E._tarefa)
		_E._tarefa = null
	var texto = _E._pendente
	_E._pendente = ""
	_E._tarefa = Compat.tarefa(load(CAMINHO_DO_SCRIPT), "_gravar", [texto])

## Chamado a cada quadro por quem grava, para a gravação pendente sair
## assim que a anterior terminar.
static func bombear() -> void:
	_bombear()

## Espera o disco antes de a máquina fechar. Sem isto, sair logo depois
## de mexer num ajuste poderia perder a última gravação.
static func encerrar() -> void:
	if _E._tarefa != null:
		Compat.esperar(_E._tarefa)
		_E._tarefa = null
	if not _E._pendente.empty():
		_gravar(_E._pendente)
		_E._pendente = ""

static func _gravar(texto: String) -> void:
	var tmp = Compat.abrir(PATH_TMP, File.WRITE)
	if tmp == null:
		return
	tmp.store_string(texto)
	tmp.close()
	var err = Compat.renomear(
		ProjectSettings.globalize_path(PATH_TMP),
		ProjectSettings.globalize_path(PATH)
	)
	if err != OK:
		Compat.apagar(ProjectSettings.globalize_path(PATH))
		Compat.renomear(
			ProjectSettings.globalize_path(PATH_TMP),
			ProjectSettings.globalize_path(PATH)
		)

static func save_data(data: Dictionary) -> bool:
	var tmp = Compat.abrir(PATH_TMP, File.WRITE)
	if tmp == null:
		return false
	tmp.store_string(JSON.print(data, "\t"))
	tmp.close()
	var err = Compat.renomear(
		ProjectSettings.globalize_path(PATH_TMP),
		ProjectSettings.globalize_path(PATH)
	)
	if err != OK:
		# Windows não renomeia por cima de arquivo existente em alguns casos.
		Compat.apagar(ProjectSettings.globalize_path(PATH))
		err = Compat.renomear(
			ProjectSettings.globalize_path(PATH_TMP),
			ProjectSettings.globalize_path(PATH)
		)
	return err == OK
