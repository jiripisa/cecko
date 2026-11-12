/// The `cecko` shell command: `cecko .` opens the current folder in the app.
public enum CommandLineLauncher {

    public static let commandName = "cecko"

    public static func script(bundleIdentifier: String) -> String {
        """
        #!/bin/sh
        # Opens a folder (default: the current one) or a file in Cecko.
        target="${1:-.}"
        if [ ! -e "$target" ]; then
            echo "cecko: $target: No such file or directory" >&2
            exit 1
        fi
        case "$target" in
            /*) ;;
            *) target="$PWD/$target" ;;
        esac
        exec open -b \(bundleIdentifier) "$target"

        """
    }
}
