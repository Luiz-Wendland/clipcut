<p align="center">
  <img src="assets/branding/clipcut-split-timeline-smooth.svg" alt="Logo do ClipCut" width="88" height="88">
</p>

<h1 align="center">ClipCut</h1>

<p align="center"><strong>Seu vídeo. Seu corte. Tudo local.</strong><br>Um editor de clipes para Windows e Linux, feito para cortar, enquadrar e exportar sem complicação.</p>

<p align="center">
  <a href="#instalação"><strong>Download</strong></a> ·
  <a href="#recursos">Recursos</a> ·
  <a href="#como-usar">Como usar</a> ·
  <a href="https://github.com/Luiz-Wendland/clipcut/issues">Ajuda e sugestões</a>
</p>

<p align="center">
  <a href="requirements.txt"><img src="https://img.shields.io/badge/Python_%C2%B7_Qt_Quick-b8a4ed" alt="Python e Qt Quick"></a>
  <a href="https://github.com/Luiz-Wendland/clipcut/releases/latest"><img src="https://img.shields.io/badge/Windows_%C2%B7_Linux-24292f" alt="Windows e Linux"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Licen%C3%A7a-MIT-b8a4ed" alt="Licença MIT"></a>
</p>

O ClipCut é um projeto pessoal: um editor de vídeo local pensado para cortar clipes com facilidade e praticidade, sem depender de um fluxo pesado de edição. Ele permite reproduzir, selecionar, enquadrar e exportar trechos; PySide6 e Qt Quick compõem a interface, enquanto FFmpeg e ffprobe cuidam da mídia. Os arquivos permanecem no computador.

## Vídeo promocional

https://github.com/user-attachments/assets/8a3c64b4-8a26-4dd4-8bfa-653ddabd03ba

O vídeo promocional e seu projeto Remotion ficam em [`promo/`](promo/README.md). A interface do vídeo é reconstruída em React/CSS a partir dos componentes e tokens QML reais; a prévia dentro do player é uma ilustração original gerada por código.

## Recursos

| Recurso | O que você pode fazer |
|---|---|
| **Corte na timeline** | Marcar início e fim, ajustar a seleção e navegar com miniaturas e waveform de áudio. |
| **Enquadramento** | Escolher proporções para redes sociais ou um recorte livre, com reposicionamento da moldura. |
| **Exportação** | Usar H.264, HEVC, AV1 ou cópia do vídeo; ajustar qualidade, áudio e tamanho-alvo. |
| **CPU ou GPU** | Escolher o encoder explicitamente, conforme os recursos do FFmpeg, da GPU e do driver. |
| **Fila de cortes** | Preparar várias exportações, cada uma com suas próprias opções. |
| **Aparência** | Usar o tema do ClipCut ou as cores do KDE Plasma, com opção de reduzir animações. |
| **Privacidade** | Trabalhar com arquivos locais, sem enviar seus vídeos a um servidor. |

## Instalação

| Sistema | Download |
|---|---|
| **Windows — instalador** | [Baixar MSI](https://github.com/Luiz-Wendland/clipcut/releases/download/v0.1.0/ClipCut-windows-x86_64.msi) — instalação em `Program Files`, com permissão de administrador. |
| **Windows — portátil** | [Baixar ZIP](https://github.com/Luiz-Wendland/clipcut/releases/download/v0.1.0/ClipCut-windows-x86_64.zip) — extraia e execute `main.exe`. |
| **Linux — AppImage** | [Baixar AppImage](https://github.com/Luiz-Wendland/clipcut/releases/download/v0.1.0/ClipCut-x86_64.AppImage) — dê permissão de execução e abra o arquivo. |
| **Linux — arquivo compactado** | [Baixar tar.gz](https://github.com/Luiz-Wendland/clipcut/releases/download/v0.1.0/ClipCut-linux-x86_64.tar.gz) — extraia e consulte `README-BINARY.txt`. |
| **Código-fonte** | Siga [Requisitos e execução](#requisitos-e-execução). |

Os pacotes são para **x86_64** e incluem Qt/Python. **Instale FFmpeg e ffprobe separadamente** e deixe ambos acessíveis pelo `PATH`.

[Todas as versões e notas de lançamento](https://github.com/Luiz-Wendland/clipcut/releases).

Esta é uma versão inicial. O CI verifica testes e geração dos pacotes, mas não substitui testes de instalação em cada sistema. Os pacotes Windows não são assinados digitalmente e podem gerar avisos de segurança. A compatibilidade de codecs e aceleração por GPU depende da instalação local.

## Interface

O tema padrão combina superfícies escuras, detalhes lavanda e controles compactos. Em **Preferências → Aparência**, é possível alternar entre o tema do ClipCut e as cores do KDE Plasma quando disponíveis; também há uma opção para reduzir animações.

## Requisitos e execução

- Python 3.10 ou superior.
- PySide6 6.8 ou superior, com os módulos QML Qt Quick, Controls, Dialogs, Layouts, Effects, Shapes, VectorImage e Qt Multimedia.
- FFmpeg e ffprobe acessíveis pelo `PATH`.
- Para codificação por GPU, drivers e encoders compatíveis na instalação do FFmpeg (opcional).

```sh
python -m pip install -r requirements.txt
python main.py
```

Instale o FFmpeg pelo gerenciador de pacotes do seu sistema antes de iniciar o app.

## Como usar

1. Abra um vídeo com **Abrir** ou arraste um arquivo local para a janela. Caminhos com espaços e Unicode são aceitos.
2. Reproduza na prévia. Use os controles flutuantes, mute e o painel **Áudio** para o volume.
3. Use **Espaço** para pausar/retomar, **I/O** para marcar IN/OUT e **←/→** para avançar um quadro. Edite os tempos na faixa de seleção ou arraste as alças da timeline. Use **+ / −** ou **Ctrl+roda** para zoom (até 4×), **Shift+roda** para navegar e duplo clique para ajustar o clipe inteiro. A timeline usa até 48 miniaturas individuais, revela mais amostras conforme o zoom e preserva a proporção dos quadros. Quando houver áudio, mostra uma waveform de picos; sem faixa de áudio, indica isso na própria timeline.
4. Use **Enquadrar** para proporções Original, 4:3, 16:9, 21:9, vertical 9:16, quadrada 1:1, retrato 4:5 ou Livre (ex.: `3:2`); reposicione a moldura diretamente sobre o vídeo.
5. **Exportar** abre um painel contextual para codec, encoder (CPU/GPU quando compatível), qualidade, proporção, áudio, tamanho-alvo e pasta. A última pasta escolhida permanece como destino padrão nas próximas exportações. Exporte imediatamente ou adicione o corte à fila; cada item guarda as opções e o intervalo escolhidos. A preferência de encoder também fica em Preferências. Escolha o nome e formato (`.mp4`/`.mkv`); se já existir, o app pede confirmação antes de substituir.

Durante a renderização, o editor fica desfocado e bloqueado; o cartão central mostra o progresso e mantém **Cancelar** disponível.

## Precisão e exportação

- H.264, HEVC, AV1 e cópia do vídeo usam encoders disponíveis no FFmpeg. Valores de qualidade são específicos de cada encoder.
- A escolha entre CPU e GPU é explícita no painel de exportação. A disponibilidade de NVENC, AMD AMF, Intel Quick Sync ou VA-API depende da GPU, do driver e dos encoders do FFmpeg. Se o encoder GPU selecionado falhar ao iniciar, a exportação informa o erro em vez de trocar silenciosamente para CPU. Algumas GPUs não codificam certos codecs por hardware: por exemplo, a RTX 3060 Ti não oferece codificação AV1; nesse caso, AV1 usa CPU e a opção GPU fica indisponível.
- **Preferências → Diagnóstico de exportação** mostra as versões e os encoders detectados e permite copiar um relatório. Ele não inclui caminhos de mídia; confira o modelo da GPU antes de compartilhar.
- As faixas de áudio são codificadas em AAC a 192 kb/s por faixa; podem ser excluídas no painel de exportação.
- Enquadrar exige recodificação e não funciona com vídeo sem recodificação. Tamanho-alvo usa bitrate estimado de uma passagem e não promete tamanho exato.
- A posição do player usa milissegundos. Botões de quadro usam o FPS médio e não garantem avanço exato em vídeos com taxa variável.
- Vídeo sem recodificação pode ajustar os pontos de corte a quadros-chave; recodificar é a opção mais precisa.
- A exportação usa arquivo temporário, valida pacotes de vídeo e publica por rename atômico. Falha/cancelamento não substitui destino existente. O original é rejeitado.

## Verificações

```sh
python -m unittest discover -s tests -v
qmllint Main.qml DesignTokens.qml components/*.qml
```

Os testes cobrem proporções, enquadramento, seleção de encoder, exportação e proteção contra sobrescrita. A disponibilidade dos módulos Qt e do `qmllint` varia conforme a instalação do Qt.

## Pacotes

Os pacotes Windows incluem o ZIP portátil e o instalador MSI; Linux inclui AppImage e tar.gz. Todos incluem o aplicativo e as dependências Qt/Python; FFmpeg e ffprobe devem ser instalados separadamente e estar no `PATH`.

## Licença

O ClipCut é distribuído sob a licença MIT; consulte o arquivo `LICENSE`. PySide6/Qt e FFmpeg são dependências externas e mantêm suas próprias licenças. Ao redistribuir uma versão empacotada, verifique e inclua os avisos aplicáveis às versões e builds utilizadas.
