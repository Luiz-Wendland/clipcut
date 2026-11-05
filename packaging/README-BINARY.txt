ClipCut — pacote independente

O Python e o Qt já estão incluídos neste pacote. Os programas de linha de
comando ffmpeg e ffprobe não estão incluídos: instale-os pelo gerenciador de
pacotes do sistema e confirme que ambos estão disponíveis no PATH para abrir,
analisar e exportar vídeos. O backend interno de reprodução do Qt é separado.

Linux tar.gz: execute ./ClipCut
Windows zip: execute main.exe
Windows MSI: install ClipCut, then launch main.exe from the install folder.
AppImage: torne o arquivo executável e abra-o; FFmpeg e ffprobe continuam
           sendo necessários no PATH.

Consulte README.md para controles, codecs, limitações e solução de problemas.
O projeto ClipCut está sob MIT (LICENSE). Qt/PySide6 e os demais componentes
empacotados mantêm licenças próprias; consulte README.md e os avisos dos
respectivos fornecedores antes de redistribuir o pacote.
