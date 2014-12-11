#!/bin/bash
# Various bash bitcoin tools
#
# requires dc, the unix desktop calculator (which should be included in the
# 'bc' package)
#
# This script requires bash version 4 or above.
#
# This script uses GNU tools.  It is therefore not guaranted to work on a POSIX
# system.
# 
# Copyright (C) 2013 Lucien Grondin (grondilu@yahoo.fr)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


declare -a base58=(
      1 2 3 4 5 6 7 8 9
    A B C D E F G H   J K L M N   P Q R S T U V W X Y Z
    a b c d e f g h i j k   m n o p q r s t u v w x y z
)
unset dcr; for i in {0..57}; do dcr+="${i}s${base58[i]}"; done
declare ec_dc='
I16i7sb0sa[[_1*lm1-*lm%q]Std0>tlm%Lts#]s%[Smddl%x-lm/rl%xLms#]s~
483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
2 100^d14551231950B75FC4402DA1732FC9BEBF-so1000003D1-ddspsm*+sGi
[_1*l%x]s_[+l%x]s+[*l%x]s*[-l%x]s-[l%xsclmsd1su0sv0sr1st[q]SQ[lc
0=Qldlcl~xlcsdscsqlrlqlu*-ltlqlv*-lulvstsrsvsulXx]dSXxLXs#LQs#lr
l%x]sI[lpSm[+q]S0d0=0lpl~xsydsxd*3*lal+x2ly*lIx*l%xdsld*2lx*l-xd
lxrl-xlll*xlyl-xrlp*+Lms#L0s#]sD[lpSm[+q]S0[2;AlDxq]Sdd0=0rd0=0d
2:Alp~1:A0:Ad2:Blp~1:B0:B2;A2;B=d[0q]Sx2;A0;B1;Bl_xrlm*+=x0;A0;B
l-xlIxdsi1;A1;Bl-xl*xdsld*0;Al-x0;Bl-xd0;Arl-xlll*x1;Al-xrlp*+L0
s#Lds#Lxs#Lms#]sA[rs.0r[rl.lAxr]SP[q]sQ[d0!<Qd2%1=P2/l.lDxs.lLx]
dSLxs#LPs#LQs#]sM[lpd1+4/r|]sR
';

decodeBase58() {
    echo -n "$1" | sed -e's/^\(1*\).*/\1/' -e's/1/00/g'
    dc -e "$dcr 16o0$(sed 's/./ 58*l&+/g' <<<$1)p" |
    while read n; do echo -n ${n/\\/}; done
}
encodeBase58() {
    echo -n "$1" | sed -e's/^\(\(00\)*\).*/\1/' -e's/00/1/g'
    dc -e "16i ${1^^} [3A ~r d0<x]dsxx +f" |
    while read -r n; do echo -n "${base58[n]}"; done
}

checksum() {
    perl -we "print pack 'H*', '$1'" |
    openssl dgst -sha256 -binary |
    openssl dgst -sha256 -binary |
    perl -we "print unpack 'H8', join '', <>"
}

checkBitcoinAddress() {
    if [[ "$1" =~ ^[$(IFS= ; echo "${base58[*]}")]+$ ]]
    then
        local h="$(decodeBase58 "$1")"
        checksum "${h:0:-8}" | grep -qi "^${h:${#h}-8}$"
    else return 2
    fi
}

hash160() {
    openssl dgst -sha256 -binary |
    openssl dgst -rmd160 -binary |
    perl -we "print unpack 'H*', join '', <>"
}

hexToAddress() {
    local x="$(printf "%2s%${3:-40}s" ${2:-00} $1 | sed 's/ /0/g')"
    encodeBase58 "$x$(checksum "$x")"
    echo
}

newBitcoinKey() {
    if [[ "$1" =~ ^[5KL] ]] && checkBitcoinAddress "$1"
    then
	local decoded="$(decodeBase58 "$1")"
	if [[ "$decoded" =~ ^80([0-9A-F]{64})(01)?[0-9A-F]{8}$ ]]
	then $FUNCNAME "0x${BASH_REMATCH[1]}"
	fi
    elif [[ "$1" =~ ^[0-9]+$ ]]
    then $FUNCNAME "0x$(dc -e "16o$1p")"
    elif [[ "${1^^}" =~ ^0X([0-9A-F]{1,64})$ ]]
    then 
	local exponent="${BASH_REMATCH[1]}"
	local uncompressed_wif="$(hexToAddress "$exponent" 80 64)"
	local compressed_wif="$(hexToAddress "${exponent}01" 80 66)"
	dc -e "$ec_dc lG I16i${exponent^^}ri lMx 16olm~ n[ ]nn" |
	{
	    read y x
	    X="$(printf "%64s" $x| sed 's/ /0/g')"
	    Y="$(printf "%64s" $y| sed 's/ /0/g')"
	    if [[ "$y" =~ [02468ACE]$ ]]
	    then y_parity="02"
	    else y_parity="03"
	    fi
	    uncompressed_addr="$(hexToAddress "$(perl -e "print pack q(H*), q(04$X$Y)" | hash160)")"
	    compressed_addr="$(hexToAddress "$(perl -e "print pack q(H*), q($y_parity$X)" | hash160)")"
	    echo ---
            echo "secret exponent:          0x$exponent"
	    echo "public key:"
	    echo "    X:                    $X"
	    echo "    Y:                    $Y"
            echo "compressed:"
            echo "    WIF:                  $compressed_wif"
            echo "    bitcoin address:      $compressed_addr"
            echo "uncompressed:"
            echo "    WIF:                  $uncompressed_wif"
            echo "    bitcoin address:      $uncompressed_addr"
	}
    elif test -z "$1"
    then $FUNCNAME "0x$(openssl rand -rand <(date +%s%N; ps -ef) -hex 32 2>&-)"
    else
	echo unknown key format "$1" >&2
	return 2
    fi
}

vanityAddressFromPublicPoint() {
    if [[ "$1" =~ ^04([0-9A-F]{64})([0-9A-F]{64})$ ]]
    then
	dc <<<"$ec_dc 16o
	0 ${BASH_REMATCH[1]} ${BASH_REMATCH[2]} rlp*+ 
	[lGlAxdlm~rn[ ]nn[ ]nr1+prlLx]dsLx
	" |
	while read -r x y n
	do
	    local public_key="$(printf "04%64s%64s" $x $y | sed 's/ /0/g')"
	    local h="$(perl -e "print pack q(H*), q($public_key)" | hash160)"
	    local addr="$(hexToAddress "$h")"
	    if [[ "$addr" =~ "$2" ]]
	    then
		echo "FOUND! $n: $addr"
		return
	    else echo "$n: $addr"
	    fi
	done
    else 
	echo unexpected format for public point >&2
	return 1
    fi
}
