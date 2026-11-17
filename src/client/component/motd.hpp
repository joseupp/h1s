#pragma once

namespace motd
{
	// Mensajes en el orden en que se mandan (el primero es el mensaje del día): contenido JSON
	using featured_content_t = std::vector<std::string>;

	featured_content_t get_featured_content();
}
