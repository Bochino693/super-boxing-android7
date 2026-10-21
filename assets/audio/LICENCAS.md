# Origem dos áudios

Todos os sons de torcida e as vinhetas são sintetizados pelo próprio
projeto — nenhuma gravação externa:

- `tools/gerar_sons_arcade.py` (build 116): `arena_ambiente`,
  `arena_publico`, `torcida_incentivo`, `torcida_festa`, `good_player`,
  `torcida_top20`, `torcida_top10`, `torcida_podio` e `torcida_recorde`.
  Plateia só com vozes graves (filtro corta o agudo acima de ~2 kHz),
  batida de pé, palmas e fanfarra de metais em estilo fliperama.
- `tools/gerar_torcida.py`: `torcida_vaia` (70 vozes com formantes de "u",
  apitos e reverberação).

Até a build 115 as torcidas usavam a gravação "Cheer 2" (jayfrosting,
Freesound 333404, CC0 1.0) e uma gravação de ginásio enviada pelo
operador; as duas tinham gritos agudos e saíram do projeto.
