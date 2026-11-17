#include "io.hpp"
#include "properties.hpp"

namespace utils::properties
{
	// Sin AppData: claves, binario parcheado y demás datos del cliente van en la carpeta h1s del juego
	std::filesystem::path get_appdata_path()
	{
		static auto data_path = std::filesystem::current_path() / "h1s";
		return data_path;
	}
}
