#include <std_include.hpp>
#include "loader/component_loader.hpp"

#include "console.hpp"
#include "motd.hpp"

#include "game/game.hpp"

#include <utils/io.hpp>

// Panel "Destacado" del menú: antes se descargaba de la web de h1-mod (anuncio de Discord, etc.). Ahora sale de los
// archivos de h1s/marketing de la carpeta del juego:
//   motd.json: el primer mensaje que se manda es el mensaje del día (ventana al entrar); sin él, el primer mensaje del
//              panel pasaba a serlo y el panel se quedaba vacío
//   el resto de *.json, por orden de nombre (01_..., 02_...): los mensajes del panel "Destacado"
//
// Formato de cada archivo (el de los mensajes de marketing del juego):
// {
//     "action_title": "Texto del panel",
//     "title": "<h2>Título de la ventana</h2>",
//     "image": "h1_motd_360x200_mp_crash",
//     "content_short": "",
//     "content_long": "<body>Texto de la ventana<br/>Otra línea</body>",
//     "popup_action_title": "Press ^2[ESC]^7 or ^2[ENTER]^7 to close",
//     "popup_action": "",
//     "popup_image": "h1_motd_620x580_mp_crash",
//     "action": "popup",
//     "noHtml": false
// }

namespace motd
{
	namespace
	{
		const std::string marketing_folder = "h1s/marketing";
	}

	featured_content_t get_featured_content()
	{
		featured_content_t content{};
		const auto motd_file = marketing_folder + "/motd.json";

		if (!utils::io::directory_exists(marketing_folder))
		{
			return content;
		}

		std::string data{};
		if (utils::io::read_file(motd_file, &data) && !data.empty())
		{
			content.push_back(data);
		}

		std::vector<std::string> files = utils::io::list_files(marketing_folder);
		std::sort(files.begin(), files.end());

		for (const auto& file : files)
		{
			if (!file.ends_with(".json") || file == motd_file)
			{
				continue;
			}

			if (utils::io::read_file(file, &data) && !data.empty())
			{
				content.push_back(data);
			}
		}

		return content;
	}
}
