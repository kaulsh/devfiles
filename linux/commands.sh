# Loaded in zsh via ~/.zshrc.d/devfiles.zsh, which is sourced from ~/.zshrc:
#   for f in "$HOME/.zshrc.d"/*.zsh(N); do source "$f"; done
#
# ~/.zshrc.d/devfiles.zsh:
#   source "$HOME/Workspace/@kaulsh/devfiles/linux/commands.sh"

calc () {
	echo "scale=4; $@" | bc -l;
}

scalc () {
	local -x BC_LINE_LENGTH=0
	printf "%.4e\n" $(echo "scale=6; $@" | bc -l)
}

cpdf () {
	gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/printer -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$1"-cmp.pdf "$1".pdf
}

getip () {
	echo "IPv4: $(curl -s ipv4.icanhazip.com)"
	echo "IPv6: $(curl -s ipv6.icanhazip.com)"
}

mkdirc () {
	mkdir -p "$1" && cd "$1" || echo "Failed to create directory $1"
}

install_skill () {
	path_to_skill="$(pwd)/$1"
	claude_path="$HOME/.claude/skills"
	cursor_path="$HOME/.cursor/skills"

	ln -sf "$path_to_skill" "$claude_path"
	ln -sf "$path_to_skill" "$cursor_path"
}

kill_port () {
	sudo fuser -k "$1"/tcp
}

curves () {
        sudo asusctl fan-curve --mod-profile $0 --enable-fan-curves true;
}

alias clear_ram_cache="sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'"
