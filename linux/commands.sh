# Place/Execute in your ~/.bashrc file

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

kill_port () {
  sudo fuser -k "$1"/tcp
}

alias clear_ram_cache="sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'"
