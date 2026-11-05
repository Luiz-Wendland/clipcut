<p align="center">
  <img src="assets/branding/clipcut-split-timeline-smooth.svg" alt="Logo do ClipCut" width="88" height="88">
</p>

<h1 align="center">ClipCut</h1>

<p align="center">Editor de clipes para Windows e Linux. Corte, enquadre e exporte vídeos localmente.</p>

<p align="center">
  <a href="#download">Download</a> ·
  <a href="#como-usar">Como usar</a> ·
  <a href="https://github.com/Luiz-Wendland/clipcut/issues">Reportar problema</a>
</p>

<p align="center">
  <a href="requirements.txt"><img src="https://img.shields.io/badge/Python_%C2%B7_Qt_Quick-b8a4ed" alt="Python e Qt Quick"></a>
  <a href="https://github.com/Luiz-Wendland/clipcut/releases/latest"><img src="https://img.shields.io/badge/Windows_%C2%B7_Linux-24292f" alt="Windows e Linux"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Licen%C3%A7a-MIT-b8a4ed" alt="Licença MIT"></a>
</p>

https://github.com/user-attachments/assets/8a3c64b4-8a26-4dd4-8bfa-653ddabd03ba

Vídeo ilustrativo da interface. [Projeto da promoção](promo/README.md).

## Download

| Windows | Linux |
|---|---|
| [Instalador MSI](https://github.com/Luiz-Wendland/clipcut/releases/download/v0.1.0/ClipCut-windows-x86_64.msi) | [AppImage](https://github.com/Luiz-Wendland/clipcut/releases/download/v0.1.0/ClipCut-x86_64.AppImage) |
| [ZIP portátil](https://github.com/Luiz-Wendland/clipcut/releases/download/v0.1.0/ClipCut-windows-x86_64.zip) | [tar.gz](https://github.com/Luiz-Wendland/clipcut/releases/download/v0.1.0/ClipCut-linux-x86_64.tar.gz) |

Pacotes **x86_64**, com Python e Qt incluídos. **Instale FFmpeg e ffprobe separadamente e deixe ambos no `PATH`.**

No ZIP, extraia e abra `main.exe`; no tar.gz, execute `./ClipCut`. Dê permissão de execução ao AppImage antes de abri-lo. O MSI exige administrador. Os pacotes Windows não são assinados digitalmente.

[Todas as versões](https://github.com/Luiz-Wendland/clipcut/releases).

## Como usar

1. Abra ou arraste um vídeo para a janela.
2. Marque o início e o fim na timeline com miniaturas e waveform.
3. Use **Enquadrar** para ajustar a proporção e o recorte.
4. Em **Exportar**, escolha codec, qualidade e destino. Exporte ou adicione à fila.

**Atalhos:** Espaço para reproduzir/pausar, I/O para início/fim e ←/→ para avançar ou voltar um quadro.

H.264, HEVC, AV1 e aceleração por GPU dependem dos encoders e drivers disponíveis. Copiar vídeo sem recodificar limita o corte aos quadros-chave e não permite recorte. O tamanho-alvo é uma estimativa.

## Executar pelo código-fonte

Requer Python 3.10+, PySide6 6.8+, FFmpeg e ffprobe.

```sh
python -m pip install -r requirements.txt
python main.py
```

Para rodar os testes:

```sh
python -m unittest discover -s tests -v
```

## Licença

[MIT](LICENSE). Qt/PySide6 e FFmpeg mantêm suas próprias licenças.
