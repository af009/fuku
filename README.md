<div align="center">
  <img alt="fuku" src='icon.png' height="200px">
</div>

# Fuku - Ollama Integration for Godot

Fuku is a plugin for [Godot Engine](https://godotengine.org/) that integrates [Ollama](https://ollama.ai), allowing you to leverage its capabilities within your Godot projects.

## ⚠️ Prerequisites

Before using Fuku, make sure you have installed and running [Ollama](https://ollama.ai) with one of the available models on your machine.

## Installation

To install the Fuku plugin in your Godot project, follow these simple steps:

1. Clone or download this repository.
2. Move the `addons/` folder to your Godot project directory.
3. In the Godot editor, navigate to `Project` > `Project Settings` > `Plugins`.
4. Click the "Enable" button.

You should now see the Fuku plugin listed in the installed plugins section of the Project Settings.

## Usage

By default, Fuku is pre-configured to use the `llama2` model with a content instruction to act as a knowledgeable Godot assistant. However, you can easily customize it to use any installed model or provide your own instructions.

To interact with Fuku, follow these steps:

1. Select the Fuku tab in the editor interface.
2. (Optional) Set a different model by modifying the "Model" field.
3. (Optional) Customize the content instruction for the model by editing the "Content" field.
4. Start chatting!.

<img src='docs/fuku.png' width='40%'>

## License

This plugin is released under the [MIT License](LICENSE).

## Support

If you encounter any issues or have questions about the Fuku plugin, please open an issue on this repository. We'll be happy to assist you or address any concerns you may have.