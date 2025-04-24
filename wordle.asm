offset 02000h

start:
	call init_rng
	call init_word

	ld   6
	st   #16 ; chance counter
	st   #17 ; correct answer vector

	ld   HELP
	st   #0
	ldh  HELP
	st   #1
	call puts
loop:
	ld   '<'
	st   #0
	call putc

	ld   '0'
	add  #16
	st   #0
	call putc

	ld   PROMPT
	st   #0
	ldh  PROMPT
	st   #1
	call puts

	ld   guess
	st   #0
	ldh  guess
	st   #1
	call gets

	call check_answer
	ld   #1
	st   #17

	call print_answer

	ld   #17
	teq  00011111b
	sjc  won

	ld   #16
	sub  1
	st   #16
	tgt  0
	sjc  loop

	sj   lost

won:
	ld   SCORE_A
	st   #0
	ldh  SCORE_A
	st   #1
	call puts

	ld   #16
	add  '0'
	st   #0
	call putc

	ld   SCORE_B
	st   #0
	ldh  SCORE_B
	st   #1
	call puts

lost:
	ld   ANSWER
	st   #0
	ldh  ANSWER
	st   #1
	call puts

	ld   word
	st   #0
	ldh  word
	st   #1
	call puts

	ld   '\n'
	st   #0
	call putc

	ret


letter_present:
	; #0: letter to be checked
	; c = set iff #0 in word

	pshb

	ldb  word

.letter_present.loop:
	ld   #b
	inc

	teq  #0
	sjc  .letter_present.ret

	tne  0
	sjc  .letter_present.loop

.letter_present.ret:
	ret


init_rng:
	pshb

	call time_get
	ld   #0
	st   #1
	call time_get
	call math_seed

	ret


init_word:
	pshb

	; get a random number mod 2048
	call math_rand
	ld   #1
	and  00000111b
	st   #1

	; keep #0 >> 5 for carry
	ld   #0
	shr  5
	st   #2

	; multiply by 8
	ld   #0
	shl  3
	st   #0
	ld   #1
	shl  3
	or   #2
	st   #1

	; add to the base (WORDS) and move to [#3, #2]
	ld   WORDS
	add  #0
	st   #2
	ldh  WORDS
	adc  #1
	st   #3

	; copy the word to #word
	ld   word
	st   #0
	ldh  word
	st   #1

	ld   5
	st   #4
	ld   0
	st   #5
	call memcpy

	ret


check_answer:
	; #0 = vector #0[n] := nth letter is present in the solution
	; #1 = vector #1[n] := nth letter was guessed right

	pshb

	; init local variables
	pshm #16
	pshm #17
	pshm #18

	ld   0
	st   #16 ; first vector  (present letters)
	st   #17 ; second vector (correct letters)
	st   #18 ; loop counter

	; compare words
.check_answer.loop:
	; run strchr on guess[#18]:
	ldb  guess ; store the currently tested letter in #2
	ld   #18
	ld   #b+a  ; #b+a is basically word[#18]
	st   #2

	; set [#1, #0] pointer
	ld   word
	st   #0
	ldh  word
	st   #1

	call strchr

	; at this point:
	; if c == 1 the letter is present in the solution, so
	; add presence bit to the #16 vector
	ld   0
	adc  0
	shl  #18
	or   #16
	st   #16

	; calculate and add correctness bit to the #17 vector
	ldb  word
	ld   #18
	ld   #b+a
	st   #0
	ldb  guess
	ld   #18
	ld   #b+a
	teq  #0

	ld   0
	adc  0
	shl  #18
	or   #17
	st   #17

	; now the loop conditions
	ld   #18
	add  1
	st   #18
	tlt  5
	sjc  .check_answer.loop

	; on loop break, move answers to #0 and #1 and deinit
	ld   #16
	st   #0
	ld   #17
	st   #1

.check_answer.ret:
	popm #18
	popm #17
	popm #16

	ret


print_answer:
	; #0: vector #0[n] := nth letter is present in the solution
	; #1: vector #1[n] := nth letter was guessed right

	pshb

	; init local variables
	pshm #16
	pshm #17
	pshm #18

	ld   #0
	st   #16
	ld   #1
	st   #17 ; because #0 and #1 are not preserved

	ld   0
	st   #18 ; current guessed character index

	ld   TEMPLATE
	st   bl
	ldh  TEMPLATE
	st   bh

	; routine body
.print_answer.loop:
	ld   #b

	teq  '\0'
	sjc  .print_answer.ret
	teq  '.'
	sjc  .print_answer.putc

	st   #0

	pshb
	call putc
	popb

.print_answer.continue:
	inc

	sj   .print_answer.loop

.print_answer.ret:
	popm #18
	popm #17
	popm #16

	ret

.print_answer.putc:
	ld   #17
	and  1
	teq  1
	sjc  .print_answer.correct

	ld   #16
	and  1
	teq  1
	sjc  .print_answer.present

.print_answer.else:
	pshb
	ldb  guess
	ld   #18
	ld   #b+a
	st   #0
	call putc
	call clear_color
	popb

	ld   #16
	shr  1
	st   #16
	ld   #17
	shr  1
	st   #17

	ld   #18
	add  1
	st   #18
	sj   .print_answer.continue

.print_answer.correct:
	pshb
	ld   2
	st   #0
	call set_color
	popb
	sj   .print_answer.else

.print_answer.present:
	pshb
	ld   3
	st   #0
	call set_color
	popb
	sj   .print_answer.else


set_color:
	; #0: color number

	pshb
	pshm #16

	ld   #0
	st   #16

	ld   SETCOLOR
	st   #0
	ldh  SETCOLOR
	st   #1
	call puts

	ld   '0'
	add  #16
	st   #0
	call putc

	ld   'm'
	st   #0
	call putc

	popm #16

	ret


clear_color:
	; #0: color number

	pshb

	ld   CLEARCOLOR
	st   #0
	ldh  CLEARCOLOR
	st   #1
	call puts

	ret


include "lib/io.asm"
include "lib/math.asm"
include "lib/mem.asm"
include "lib/string.asm"
include "lib/time.asm"


word:  "!!!!!" 0
guess: "                                " 0

PROMPT:     "> " 0

SETCOLOR:   "\e[1;3" 0
CLEARCOLOR: "\e[0m" 0

TEMPLATE:
	"\n"
	" #######  #######  #######  #######  #######\n"
	" #     #  #     #  #     #  #     #  #     #\n"
	" #  .  #  #  .  #  #  .  #  #  .  #  #  .  #\n"
	" #     #  #     #  #     #  #     #  #     #\n"
	" #######  #######  #######  #######  #######\n"
	"\n" 0

HELP:
	"You have 6 chances to guess a random 5-letter word.\n"
	"Letters typed in \e[1;33myellow\e[0m are present in the word.\n"
	"Those typed in \e[1;32mgreen\e[0m are additionally"
	" in the right place.\n\n"
	"Type your 5-letter guesses in lowercase.\n"
	"\n" 0

ANSWER:
	"The correct answer is: " 0

SCORE_A:  "You scored " 0
SCORE_B:  " points!\n" 0

; 2048 words, each 8-byte-padded
WORDS:
	"aback" 0 0 0 "abase" 0 0 0 "abate" 0 0 0 "abbey" 0 0 0
	"abbot" 0 0 0 "abhor" 0 0 0 "abled" 0 0 0 "abode" 0 0 0
	"abort" 0 0 0 "about" 0 0 0 "abuse" 0 0 0 "abyss" 0 0 0
	"acorn" 0 0 0 "acrid" 0 0 0 "actor" 0 0 0 "acute" 0 0 0
	"adage" 0 0 0 "adapt" 0 0 0 "adept" 0 0 0 "admit" 0 0 0
	"adobe" 0 0 0 "adopt" 0 0 0 "adore" 0 0 0 "adorn" 0 0 0
	"adult" 0 0 0 "affix" 0 0 0 "afire" 0 0 0 "afoot" 0 0 0
	"afoul" 0 0 0 "after" 0 0 0 "again" 0 0 0 "agape" 0 0 0
	"agate" 0 0 0 "agent" 0 0 0 "agile" 0 0 0 "aging" 0 0 0
	"aglow" 0 0 0 "agony" 0 0 0 "agora" 0 0 0 "agree" 0 0 0
	"ahead" 0 0 0 "aider" 0 0 0 "aisle" 0 0 0 "alarm" 0 0 0
	"album" 0 0 0 "algae" 0 0 0 "alibi" 0 0 0 "alien" 0 0 0
	"align" 0 0 0 "alike" 0 0 0 "alive" 0 0 0 "allay" 0 0 0
	"alley" 0 0 0 "allot" 0 0 0 "allow" 0 0 0 "alloy" 0 0 0
	"aloft" 0 0 0 "alone" 0 0 0 "along" 0 0 0 "aloof" 0 0 0
	"aloud" 0 0 0 "alpha" 0 0 0 "altar" 0 0 0 "alter" 0 0 0
	"amass" 0 0 0 "amaze" 0 0 0 "amber" 0 0 0 "amble" 0 0 0
	"amend" 0 0 0 "amiss" 0 0 0 "amity" 0 0 0 "among" 0 0 0
	"amply" 0 0 0 "amuse" 0 0 0 "angel" 0 0 0 "anger" 0 0 0
	"angle" 0 0 0 "angry" 0 0 0 "anime" 0 0 0 "ankle" 0 0 0
	"annex" 0 0 0 "annoy" 0 0 0 "annul" 0 0 0 "anode" 0 0 0
	"antic" 0 0 0 "anvil" 0 0 0 "aorta" 0 0 0 "apart" 0 0 0
	"aphid" 0 0 0 "aping" 0 0 0 "apnea" 0 0 0 "apple" 0 0 0
	"apply" 0 0 0 "apron" 0 0 0 "aptly" 0 0 0 "arbor" 0 0 0
	"ardor" 0 0 0 "arena" 0 0 0 "argue" 0 0 0 "arise" 0 0 0
	"aroma" 0 0 0 "arose" 0 0 0 "array" 0 0 0 "arson" 0 0 0
	"artsy" 0 0 0 "ascot" 0 0 0 "ashen" 0 0 0 "aside" 0 0 0
	"askew" 0 0 0 "assay" 0 0 0 "asset" 0 0 0 "atoll" 0 0 0
	"attic" 0 0 0 "audio" 0 0 0 "audit" 0 0 0 "augur" 0 0 0
	"aunty" 0 0 0 "avail" 0 0 0 "avert" 0 0 0 "avian" 0 0 0
	"avoid" 0 0 0 "await" 0 0 0 "awake" 0 0 0 "award" 0 0 0
	"aware" 0 0 0 "awash" 0 0 0 "awful" 0 0 0 "awoke" 0 0 0
	"axiom" 0 0 0 "azure" 0 0 0 "bacon" 0 0 0 "badge" 0 0 0
	"badly" 0 0 0 "bagel" 0 0 0 "baker" 0 0 0 "banal" 0 0 0
	"banjo" 0 0 0 "barge" 0 0 0 "baron" 0 0 0 "basal" 0 0 0
	"basic" 0 0 0 "basil" 0 0 0 "basin" 0 0 0 "basis" 0 0 0
	"baste" 0 0 0 "batch" 0 0 0 "bathe" 0 0 0 "baton" 0 0 0
	"batty" 0 0 0 "bayou" 0 0 0 "beach" 0 0 0 "beady" 0 0 0
	"beard" 0 0 0 "beast" 0 0 0 "beech" 0 0 0 "beefy" 0 0 0
	"befit" 0 0 0 "began" 0 0 0 "begat" 0 0 0 "beget" 0 0 0
	"begun" 0 0 0 "being" 0 0 0 "belch" 0 0 0 "belie" 0 0 0
	"belle" 0 0 0 "belly" 0 0 0 "below" 0 0 0 "beret" 0 0 0
	"berry" 0 0 0 "berth" 0 0 0 "beset" 0 0 0 "betel" 0 0 0
	"bevel" 0 0 0 "bezel" 0 0 0 "bible" 0 0 0 "bicep" 0 0 0
	"biddy" 0 0 0 "bigot" 0 0 0 "billy" 0 0 0 "bingo" 0 0 0
	"biome" 0 0 0 "birch" 0 0 0 "birth" 0 0 0 "bison" 0 0 0
	"bitty" 0 0 0 "black" 0 0 0 "blade" 0 0 0 "blame" 0 0 0
	"bland" 0 0 0 "blank" 0 0 0 "blare" 0 0 0 "blast" 0 0 0
	"blaze" 0 0 0 "bleak" 0 0 0 "bleat" 0 0 0 "bleed" 0 0 0
	"blend" 0 0 0 "bless" 0 0 0 "blimp" 0 0 0 "blind" 0 0 0
	"blink" 0 0 0 "bliss" 0 0 0 "blitz" 0 0 0 "bloat" 0 0 0
	"blond" 0 0 0 "blood" 0 0 0 "bloom" 0 0 0 "blown" 0 0 0
	"bluer" 0 0 0 "bluff" 0 0 0 "blurb" 0 0 0 "blurt" 0 0 0
	"blush" 0 0 0 "board" 0 0 0 "boast" 0 0 0 "bobby" 0 0 0
	"boney" 0 0 0 "bongo" 0 0 0 "bonus" 0 0 0 "booby" 0 0 0
	"boost" 0 0 0 "booth" 0 0 0 "booty" 0 0 0 "booze" 0 0 0
	"boozy" 0 0 0 "borax" 0 0 0 "borne" 0 0 0 "bosom" 0 0 0
	"bossy" 0 0 0 "botch" 0 0 0 "bough" 0 0 0 "bound" 0 0 0
	"bowel" 0 0 0 "boxer" 0 0 0 "braid" 0 0 0 "brain" 0 0 0
	"brake" 0 0 0 "brand" 0 0 0 "brash" 0 0 0 "brass" 0 0 0
	"brave" 0 0 0 "bravo" 0 0 0 "brawl" 0 0 0 "bread" 0 0 0
	"break" 0 0 0 "breed" 0 0 0 "briar" 0 0 0 "bride" 0 0 0
	"brief" 0 0 0 "brine" 0 0 0 "brink" 0 0 0 "briny" 0 0 0
	"brisk" 0 0 0 "broad" 0 0 0 "broil" 0 0 0 "broke" 0 0 0
	"brood" 0 0 0 "brook" 0 0 0 "broom" 0 0 0 "brown" 0 0 0
	"brunt" 0 0 0 "brush" 0 0 0 "brute" 0 0 0 "budge" 0 0 0
	"buggy" 0 0 0 "build" 0 0 0 "built" 0 0 0 "bulge" 0 0 0
	"bulky" 0 0 0 "bully" 0 0 0 "bunch" 0 0 0 "bunny" 0 0 0
	"burly" 0 0 0 "burnt" 0 0 0 "burst" 0 0 0 "bushy" 0 0 0
	"butch" 0 0 0 "butte" 0 0 0 "buyer" 0 0 0 "bylaw" 0 0 0
	"cabal" 0 0 0 "cabin" 0 0 0 "cable" 0 0 0 "cacao" 0 0 0
	"cache" 0 0 0 "cacti" 0 0 0 "caddy" 0 0 0 "cadet" 0 0 0
	"cagey" 0 0 0 "cairn" 0 0 0 "camel" 0 0 0 "cameo" 0 0 0
	"canal" 0 0 0 "candy" 0 0 0 "canny" 0 0 0 "canoe" 0 0 0
	"canon" 0 0 0 "caput" 0 0 0 "carat" 0 0 0 "cargo" 0 0 0
	"carol" 0 0 0 "carry" 0 0 0 "caste" 0 0 0 "catch" 0 0 0
	"cater" 0 0 0 "catty" 0 0 0 "caulk" 0 0 0 "cause" 0 0 0
	"cavil" 0 0 0 "cease" 0 0 0 "cedar" 0 0 0 "cello" 0 0 0
	"chaff" 0 0 0 "chain" 0 0 0 "chair" 0 0 0 "chalk" 0 0 0
	"champ" 0 0 0 "chant" 0 0 0 "chaos" 0 0 0 "chard" 0 0 0
	"charm" 0 0 0 "chart" 0 0 0 "chase" 0 0 0 "chasm" 0 0 0
	"cheap" 0 0 0 "cheat" 0 0 0 "check" 0 0 0 "cheek" 0 0 0
	"cheer" 0 0 0 "chess" 0 0 0 "chest" 0 0 0 "chide" 0 0 0
	"chief" 0 0 0 "child" 0 0 0 "chili" 0 0 0 "chill" 0 0 0
	"chime" 0 0 0 "chock" 0 0 0 "choir" 0 0 0 "choke" 0 0 0
	"chore" 0 0 0 "chose" 0 0 0 "chuck" 0 0 0 "chunk" 0 0 0
	"churn" 0 0 0 "chute" 0 0 0 "cider" 0 0 0 "cigar" 0 0 0
	"cinch" 0 0 0 "circa" 0 0 0 "civic" 0 0 0 "civil" 0 0 0
	"claim" 0 0 0 "clamp" 0 0 0 "clang" 0 0 0 "clank" 0 0 0
	"clash" 0 0 0 "clasp" 0 0 0 "class" 0 0 0 "clean" 0 0 0
	"cleat" 0 0 0 "cleft" 0 0 0 "click" 0 0 0 "cliff" 0 0 0
	"climb" 0 0 0 "clink" 0 0 0 "cloak" 0 0 0 "clock" 0 0 0
	"clone" 0 0 0 "close" 0 0 0 "cloth" 0 0 0 "cloud" 0 0 0
	"clout" 0 0 0 "clove" 0 0 0 "clown" 0 0 0 "cluck" 0 0 0
	"clued" 0 0 0 "clump" 0 0 0 "clung" 0 0 0 "coach" 0 0 0
	"coast" 0 0 0 "cobra" 0 0 0 "cocoa" 0 0 0 "colon" 0 0 0
	"color" 0 0 0 "comet" 0 0 0 "comfy" 0 0 0 "comic" 0 0 0
	"conch" 0 0 0 "condo" 0 0 0 "conic" 0 0 0 "coral" 0 0 0
	"corer" 0 0 0 "corny" 0 0 0 "couch" 0 0 0 "cough" 0 0 0
	"count" 0 0 0 "coupe" 0 0 0 "court" 0 0 0 "coven" 0 0 0
	"cover" 0 0 0 "covet" 0 0 0 "covey" 0 0 0 "cower" 0 0 0
	"coyly" 0 0 0 "crack" 0 0 0 "cramp" 0 0 0 "crane" 0 0 0
	"crank" 0 0 0 "crash" 0 0 0 "crass" 0 0 0 "crate" 0 0 0
	"crave" 0 0 0 "crawl" 0 0 0 "craze" 0 0 0 "crazy" 0 0 0
	"creak" 0 0 0 "cream" 0 0 0 "credo" 0 0 0 "creed" 0 0 0
	"creep" 0 0 0 "creme" 0 0 0 "crept" 0 0 0 "cress" 0 0 0
	"crick" 0 0 0 "cried" 0 0 0 "crier" 0 0 0 "crime" 0 0 0
	"crimp" 0 0 0 "crisp" 0 0 0 "croak" 0 0 0 "crock" 0 0 0
	"crone" 0 0 0 "crony" 0 0 0 "crook" 0 0 0 "cross" 0 0 0
	"croup" 0 0 0 "crowd" 0 0 0 "crown" 0 0 0 "crude" 0 0 0
	"cruel" 0 0 0 "crumb" 0 0 0 "crump" 0 0 0 "crush" 0 0 0
	"crust" 0 0 0 "crypt" 0 0 0 "cubic" 0 0 0 "cumin" 0 0 0
	"curio" 0 0 0 "curly" 0 0 0 "curry" 0 0 0 "curse" 0 0 0
	"curve" 0 0 0 "curvy" 0 0 0 "cutie" 0 0 0 "cyber" 0 0 0
	"cycle" 0 0 0 "cynic" 0 0 0 "daddy" 0 0 0 "daily" 0 0 0
	"dairy" 0 0 0 "daisy" 0 0 0 "dally" 0 0 0 "dance" 0 0 0
	"dandy" 0 0 0 "dealt" 0 0 0 "death" 0 0 0 "debar" 0 0 0
	"debut" 0 0 0 "decal" 0 0 0 "decay" 0 0 0 "decor" 0 0 0
	"decoy" 0 0 0 "decry" 0 0 0 "defer" 0 0 0 "deign" 0 0 0
	"deity" 0 0 0 "delay" 0 0 0 "delta" 0 0 0 "delve" 0 0 0
	"demon" 0 0 0 "demur" 0 0 0 "denim" 0 0 0 "dense" 0 0 0
	"depot" 0 0 0 "depth" 0 0 0 "derby" 0 0 0 "deter" 0 0 0
	"deuce" 0 0 0 "devil" 0 0 0 "diary" 0 0 0 "digit" 0 0 0
	"dimly" 0 0 0 "diner" 0 0 0 "dingo" 0 0 0 "dingy" 0 0 0
	"diode" 0 0 0 "dirge" 0 0 0 "dirty" 0 0 0 "disco" 0 0 0
	"ditch" 0 0 0 "ditto" 0 0 0 "ditty" 0 0 0 "diver" 0 0 0
	"dizzy" 0 0 0 "dodge" 0 0 0 "dogma" 0 0 0 "doing" 0 0 0
	"dolly" 0 0 0 "donor" 0 0 0 "donut" 0 0 0 "dopey" 0 0 0
	"dough" 0 0 0 "dowdy" 0 0 0 "dowel" 0 0 0 "downy" 0 0 0
	"dowry" 0 0 0 "dozen" 0 0 0 "draft" 0 0 0 "drain" 0 0 0
	"drake" 0 0 0 "drama" 0 0 0 "drank" 0 0 0 "drape" 0 0 0
	"drawl" 0 0 0 "drawn" 0 0 0 "dread" 0 0 0 "dream" 0 0 0
	"dress" 0 0 0 "dried" 0 0 0 "drier" 0 0 0 "drift" 0 0 0
	"drill" 0 0 0 "drink" 0 0 0 "drive" 0 0 0 "droit" 0 0 0
	"droll" 0 0 0 "drone" 0 0 0 "drool" 0 0 0 "dross" 0 0 0
	"drove" 0 0 0 "drown" 0 0 0 "druid" 0 0 0 "drunk" 0 0 0
	"dryer" 0 0 0 "dryly" 0 0 0 "duchy" 0 0 0 "dully" 0 0 0
	"dummy" 0 0 0 "dumpy" 0 0 0 "dunce" 0 0 0 "dutch" 0 0 0
	"duvet" 0 0 0 "dwell" 0 0 0 "dying" 0 0 0 "eager" 0 0 0
	"eagle" 0 0 0 "early" 0 0 0 "earth" 0 0 0 "easel" 0 0 0
	"eaten" 0 0 0 "eater" 0 0 0 "eclat" 0 0 0 "edict" 0 0 0
	"edify" 0 0 0 "eerie" 0 0 0 "egret" 0 0 0 "eight" 0 0 0
	"eject" 0 0 0 "eking" 0 0 0 "elate" 0 0 0 "elbow" 0 0 0
	"elder" 0 0 0 "elegy" 0 0 0 "elide" 0 0 0 "elite" 0 0 0
	"elope" 0 0 0 "elude" 0 0 0 "email" 0 0 0 "embed" 0 0 0
	"ember" 0 0 0 "emcee" 0 0 0 "empty" 0 0 0 "enact" 0 0 0
	"endow" 0 0 0 "enema" 0 0 0 "enjoy" 0 0 0 "ennui" 0 0 0
	"ensue" 0 0 0 "enter" 0 0 0 "entry" 0 0 0 "envoy" 0 0 0
	"epoch" 0 0 0 "epoxy" 0 0 0 "equal" 0 0 0 "equip" 0 0 0
	"erase" 0 0 0 "erect" 0 0 0 "erode" 0 0 0 "error" 0 0 0
	"erupt" 0 0 0 "essay" 0 0 0 "ester" 0 0 0 "ether" 0 0 0
	"ethic" 0 0 0 "ethos" 0 0 0 "etude" 0 0 0 "evade" 0 0 0
	"event" 0 0 0 "every" 0 0 0 "evict" 0 0 0 "evoke" 0 0 0
	"exalt" 0 0 0 "excel" 0 0 0 "exert" 0 0 0 "exile" 0 0 0
	"exist" 0 0 0 "expel" 0 0 0 "extol" 0 0 0 "extra" 0 0 0
	"exult" 0 0 0 "eying" 0 0 0 "fable" 0 0 0 "facet" 0 0 0
	"faint" 0 0 0 "fairy" 0 0 0 "faith" 0 0 0 "false" 0 0 0
	"fancy" 0 0 0 "farce" 0 0 0 "fatal" 0 0 0 "fatty" 0 0 0
	"fault" 0 0 0 "fauna" 0 0 0 "favor" 0 0 0 "fecal" 0 0 0
	"feign" 0 0 0 "fella" 0 0 0 "felon" 0 0 0 "femme" 0 0 0
	"femur" 0 0 0 "fence" 0 0 0 "feral" 0 0 0 "ferry" 0 0 0
	"fetal" 0 0 0 "fetch" 0 0 0 "fetid" 0 0 0 "fetus" 0 0 0
	"fever" 0 0 0 "fiber" 0 0 0 "fibre" 0 0 0 "ficus" 0 0 0
	"field" 0 0 0 "fiery" 0 0 0 "fifty" 0 0 0 "fight" 0 0 0
	"filer" 0 0 0 "filet" 0 0 0 "filly" 0 0 0 "filmy" 0 0 0
	"final" 0 0 0 "finch" 0 0 0 "first" 0 0 0 "fishy" 0 0 0
	"fixer" 0 0 0 "fizzy" 0 0 0 "fjord" 0 0 0 "flack" 0 0 0
	"flail" 0 0 0 "flake" 0 0 0 "flaky" 0 0 0 "flame" 0 0 0
	"flank" 0 0 0 "flare" 0 0 0 "flash" 0 0 0 "flask" 0 0 0
	"fleck" 0 0 0 "flesh" 0 0 0 "flick" 0 0 0 "flier" 0 0 0
	"fling" 0 0 0 "flint" 0 0 0 "flirt" 0 0 0 "float" 0 0 0
	"flock" 0 0 0 "flood" 0 0 0 "floor" 0 0 0 "flora" 0 0 0
	"floss" 0 0 0 "flout" 0 0 0 "fluid" 0 0 0 "fluke" 0 0 0
	"flume" 0 0 0 "flung" 0 0 0 "flunk" 0 0 0 "flush" 0 0 0
	"flute" 0 0 0 "flyer" 0 0 0 "foamy" 0 0 0 "focal" 0 0 0
	"focus" 0 0 0 "foggy" 0 0 0 "folio" 0 0 0 "folly" 0 0 0
	"foray" 0 0 0 "force" 0 0 0 "forge" 0 0 0 "forgo" 0 0 0
	"forte" 0 0 0 "forty" 0 0 0 "forum" 0 0 0 "found" 0 0 0
	"foyer" 0 0 0 "frail" 0 0 0 "frank" 0 0 0 "fraud" 0 0 0
	"freak" 0 0 0 "freed" 0 0 0 "fresh" 0 0 0 "friar" 0 0 0
	"fried" 0 0 0 "frill" 0 0 0 "frisk" 0 0 0 "fritz" 0 0 0
	"frock" 0 0 0 "front" 0 0 0 "frost" 0 0 0 "froth" 0 0 0
	"frown" 0 0 0 "froze" 0 0 0 "fruit" 0 0 0 "fudge" 0 0 0
	"fugue" 0 0 0 "fully" 0 0 0 "fungi" 0 0 0 "funky" 0 0 0
	"funny" 0 0 0 "furry" 0 0 0 "fussy" 0 0 0 "fuzzy" 0 0 0
	"gaffe" 0 0 0 "gaily" 0 0 0 "gamer" 0 0 0 "gamut" 0 0 0
	"gassy" 0 0 0 "gaudy" 0 0 0 "gauge" 0 0 0 "gaunt" 0 0 0
	"gauze" 0 0 0 "gavel" 0 0 0 "gawky" 0 0 0 "gayer" 0 0 0
	"gayly" 0 0 0 "gazer" 0 0 0 "gecko" 0 0 0 "geeky" 0 0 0
	"geese" 0 0 0 "genie" 0 0 0 "genre" 0 0 0 "ghost" 0 0 0
	"giant" 0 0 0 "giddy" 0 0 0 "gipsy" 0 0 0 "girly" 0 0 0
	"girth" 0 0 0 "given" 0 0 0 "giver" 0 0 0 "glade" 0 0 0
	"gland" 0 0 0 "glare" 0 0 0 "glass" 0 0 0 "glaze" 0 0 0
	"glide" 0 0 0 "glint" 0 0 0 "gloat" 0 0 0 "globe" 0 0 0
	"gloom" 0 0 0 "glory" 0 0 0 "gloss" 0 0 0 "glove" 0 0 0
	"glyph" 0 0 0 "gnash" 0 0 0 "gnome" 0 0 0 "godly" 0 0 0
	"going" 0 0 0 "golem" 0 0 0 "golly" 0 0 0 "gonad" 0 0 0
	"goner" 0 0 0 "goody" 0 0 0 "gooey" 0 0 0 "goofy" 0 0 0
	"goose" 0 0 0 "gorge" 0 0 0 "gourd" 0 0 0 "grace" 0 0 0
	"grade" 0 0 0 "graft" 0 0 0 "grail" 0 0 0 "grain" 0 0 0
	"grand" 0 0 0 "grant" 0 0 0 "grape" 0 0 0 "graph" 0 0 0
	"grasp" 0 0 0 "grass" 0 0 0 "grate" 0 0 0 "grave" 0 0 0
	"gravy" 0 0 0 "graze" 0 0 0 "greed" 0 0 0 "green" 0 0 0
	"greet" 0 0 0 "grief" 0 0 0 "grill" 0 0 0 "grime" 0 0 0
	"grimy" 0 0 0 "grind" 0 0 0 "gripe" 0 0 0 "groan" 0 0 0
	"groin" 0 0 0 "grope" 0 0 0 "gross" 0 0 0 "group" 0 0 0
	"grout" 0 0 0 "grove" 0 0 0 "grown" 0 0 0 "gruel" 0 0 0
	"gruff" 0 0 0 "grunt" 0 0 0 "guard" 0 0 0 "guava" 0 0 0
	"guess" 0 0 0 "guest" 0 0 0 "guide" 0 0 0 "guild" 0 0 0
	"guile" 0 0 0 "guilt" 0 0 0 "guise" 0 0 0 "gulch" 0 0 0
	"gully" 0 0 0 "gumbo" 0 0 0 "gummy" 0 0 0 "guppy" 0 0 0
	"gusto" 0 0 0 "gusty" 0 0 0 "gypsy" 0 0 0 "habit" 0 0 0
	"hairy" 0 0 0 "halve" 0 0 0 "handy" 0 0 0 "happy" 0 0 0
	"harem" 0 0 0 "harpy" 0 0 0 "harry" 0 0 0 "harsh" 0 0 0
	"hasty" 0 0 0 "hatch" 0 0 0 "hater" 0 0 0 "haven" 0 0 0
	"havoc" 0 0 0 "hazel" 0 0 0 "heady" 0 0 0 "heard" 0 0 0
	"heart" 0 0 0 "heath" 0 0 0 "heave" 0 0 0 "heavy" 0 0 0
	"hedge" 0 0 0 "hefty" 0 0 0 "heist" 0 0 0 "helix" 0 0 0
	"hello" 0 0 0 "heron" 0 0 0 "hinge" 0 0 0 "hippo" 0 0 0
	"hippy" 0 0 0 "hitch" 0 0 0 "hoard" 0 0 0 "hoist" 0 0 0
	"holly" 0 0 0 "homer" 0 0 0 "honey" 0 0 0 "horde" 0 0 0
	"horny" 0 0 0 "horse" 0 0 0 "hotel" 0 0 0 "hotly" 0 0 0
	"hound" 0 0 0 "house" 0 0 0 "hovel" 0 0 0 "hover" 0 0 0
	"howdy" 0 0 0 "human" 0 0 0 "humph" 0 0 0 "humus" 0 0 0
	"hunky" 0 0 0 "hurry" 0 0 0 "husky" 0 0 0 "hussy" 0 0 0
	"hutch" 0 0 0 "hydro" 0 0 0 "hyena" 0 0 0 "hymen" 0 0 0
	"hyper" 0 0 0 "icily" 0 0 0 "icing" 0 0 0 "ideal" 0 0 0
	"idiom" 0 0 0 "idler" 0 0 0 "idyll" 0 0 0 "iliac" 0 0 0
	"image" 0 0 0 "imbue" 0 0 0 "impel" 0 0 0 "imply" 0 0 0
	"inane" 0 0 0 "inbox" 0 0 0 "incur" 0 0 0 "index" 0 0 0
	"inept" 0 0 0 "inert" 0 0 0 "infer" 0 0 0 "ingot" 0 0 0
	"inlay" 0 0 0 "inlet" 0 0 0 "input" 0 0 0 "inter" 0 0 0
	"intro" 0 0 0 "ionic" 0 0 0 "irate" 0 0 0 "irony" 0 0 0
	"islet" 0 0 0 "issue" 0 0 0 "itchy" 0 0 0 "ivory" 0 0 0
	"jaunt" 0 0 0 "jazzy" 0 0 0 "jelly" 0 0 0 "jerky" 0 0 0
	"jetty" 0 0 0 "jewel" 0 0 0 "jiffy" 0 0 0 "joist" 0 0 0
	"joker" 0 0 0 "jolly" 0 0 0 "joust" 0 0 0 "juice" 0 0 0
	"juicy" 0 0 0 "jumbo" 0 0 0 "jumpy" 0 0 0 "junta" 0 0 0
	"kappa" 0 0 0 "karma" 0 0 0 "kayak" 0 0 0 "kebab" 0 0 0
	"khaki" 0 0 0 "kinky" 0 0 0 "kiosk" 0 0 0 "kitty" 0 0 0
	"knack" 0 0 0 "knave" 0 0 0 "knead" 0 0 0 "kneed" 0 0 0
	"kneel" 0 0 0 "knelt" 0 0 0 "knife" 0 0 0 "knock" 0 0 0
	"knoll" 0 0 0 "known" 0 0 0 "koala" 0 0 0 "krill" 0 0 0
	"label" 0 0 0 "labor" 0 0 0 "laden" 0 0 0 "ladle" 0 0 0
	"lager" 0 0 0 "lance" 0 0 0 "lapel" 0 0 0 "lapse" 0 0 0
	"large" 0 0 0 "larva" 0 0 0 "lasso" 0 0 0 "latch" 0 0 0
	"later" 0 0 0 "lathe" 0 0 0 "latte" 0 0 0 "laugh" 0 0 0
	"layer" 0 0 0 "leaky" 0 0 0 "leant" 0 0 0 "leapt" 0 0 0
	"learn" 0 0 0 "lease" 0 0 0 "leash" 0 0 0 "least" 0 0 0
	"ledge" 0 0 0 "leech" 0 0 0 "leery" 0 0 0 "lefty" 0 0 0
	"legal" 0 0 0 "lemon" 0 0 0 "leper" 0 0 0 "level" 0 0 0
	"lever" 0 0 0 "liege" 0 0 0 "light" 0 0 0 "liken" 0 0 0
	"lilac" 0 0 0 "limbo" 0 0 0 "limit" 0 0 0 "liner" 0 0 0
	"lingo" 0 0 0 "lipid" 0 0 0 "lithe" 0 0 0 "liver" 0 0 0
	"livid" 0 0 0 "llama" 0 0 0 "loamy" 0 0 0 "loath" 0 0 0
	"lobby" 0 0 0 "lodge" 0 0 0 "lofty" 0 0 0 "logic" 0 0 0
	"login" 0 0 0 "loopy" 0 0 0 "loose" 0 0 0 "loser" 0 0 0
	"louse" 0 0 0 "lousy" 0 0 0 "lover" 0 0 0 "lower" 0 0 0
	"lowly" 0 0 0 "loyal" 0 0 0 "lucid" 0 0 0 "lucky" 0 0 0
	"lumen" 0 0 0 "lumpy" 0 0 0 "lunar" 0 0 0 "lunch" 0 0 0
	"lunge" 0 0 0 "lupus" 0 0 0 "lurch" 0 0 0 "lurid" 0 0 0
	"lusty" 0 0 0 "lying" 0 0 0 "lymph" 0 0 0 "lynch" 0 0 0
	"macaw" 0 0 0 "macro" 0 0 0 "madam" 0 0 0 "madly" 0 0 0
	"mafia" 0 0 0 "magic" 0 0 0 "magma" 0 0 0 "maize" 0 0 0
	"major" 0 0 0 "maker" 0 0 0 "mammy" 0 0 0 "mango" 0 0 0
	"mangy" 0 0 0 "mania" 0 0 0 "manic" 0 0 0 "manly" 0 0 0
	"manor" 0 0 0 "maple" 0 0 0 "march" 0 0 0 "marry" 0 0 0
	"marsh" 0 0 0 "mason" 0 0 0 "match" 0 0 0 "matey" 0 0 0
	"mauve" 0 0 0 "mayor" 0 0 0 "mealy" 0 0 0 "meant" 0 0 0
	"meaty" 0 0 0 "mecca" 0 0 0 "medal" 0 0 0 "media" 0 0 0
	"medic" 0 0 0 "melee" 0 0 0 "melon" 0 0 0 "mercy" 0 0 0
	"merge" 0 0 0 "merit" 0 0 0 "merry" 0 0 0 "metal" 0 0 0
	"meter" 0 0 0 "metro" 0 0 0 "micro" 0 0 0 "midge" 0 0 0
	"midst" 0 0 0 "might" 0 0 0 "milky" 0 0 0 "mimic" 0 0 0
	"mince" 0 0 0 "miner" 0 0 0 "minim" 0 0 0 "minor" 0 0 0
	"minty" 0 0 0 "minus" 0 0 0 "mirth" 0 0 0 "miser" 0 0 0
	"missy" 0 0 0 "mocha" 0 0 0 "modal" 0 0 0 "model" 0 0 0
	"modem" 0 0 0 "moist" 0 0 0 "molar" 0 0 0 "money" 0 0 0
	"month" 0 0 0 "moody" 0 0 0 "moose" 0 0 0 "moral" 0 0 0
	"morph" 0 0 0 "motel" 0 0 0 "motif" 0 0 0 "motor" 0 0 0
	"moult" 0 0 0 "mount" 0 0 0 "mourn" 0 0 0 "mouse" 0 0 0
	"mouth" 0 0 0 "mover" 0 0 0 "movie" 0 0 0 "mower" 0 0 0
	"mucky" 0 0 0 "mucus" 0 0 0 "muddy" 0 0 0 "mulch" 0 0 0
	"mummy" 0 0 0 "munch" 0 0 0 "mural" 0 0 0 "murky" 0 0 0
	"mushy" 0 0 0 "music" 0 0 0 "musty" 0 0 0 "myrrh" 0 0 0
	"naive" 0 0 0 "nanny" 0 0 0 "nasal" 0 0 0 "nasty" 0 0 0
	"natal" 0 0 0 "naval" 0 0 0 "navel" 0 0 0 "needy" 0 0 0
	"neigh" 0 0 0 "nerve" 0 0 0 "never" 0 0 0 "newer" 0 0 0
	"newly" 0 0 0 "nicer" 0 0 0 "niche" 0 0 0 "niece" 0 0 0
	"night" 0 0 0 "ninja" 0 0 0 "ninny" 0 0 0 "noble" 0 0 0
	"nobly" 0 0 0 "noise" 0 0 0 "noisy" 0 0 0 "noose" 0 0 0
	"north" 0 0 0 "notch" 0 0 0 "novel" 0 0 0 "nudge" 0 0 0
	"nurse" 0 0 0 "nutty" 0 0 0 "nylon" 0 0 0 "nymph" 0 0 0
	"oaken" 0 0 0 "occur" 0 0 0 "octal" 0 0 0 "octet" 0 0 0
	"odder" 0 0 0 "oddly" 0 0 0 "offal" 0 0 0 "often" 0 0 0
	"olden" 0 0 0 "older" 0 0 0 "olive" 0 0 0 "ombre" 0 0 0
	"omega" 0 0 0 "onion" 0 0 0 "onset" 0 0 0 "opera" 0 0 0
	"opine" 0 0 0 "opium" 0 0 0 "optic" 0 0 0 "orbit" 0 0 0
	"order" 0 0 0 "organ" 0 0 0 "other" 0 0 0 "ought" 0 0 0
	"ounce" 0 0 0 "outdo" 0 0 0 "outer" 0 0 0 "outgo" 0 0 0
	"ovary" 0 0 0 "ovate" 0 0 0 "ovine" 0 0 0 "ovoid" 0 0 0
	"owing" 0 0 0 "owner" 0 0 0 "oxide" 0 0 0 "ozone" 0 0 0
	"paddy" 0 0 0 "pagan" 0 0 0 "paint" 0 0 0 "paler" 0 0 0
	"palsy" 0 0 0 "panel" 0 0 0 "panic" 0 0 0 "pansy" 0 0 0
	"papal" 0 0 0 "paper" 0 0 0 "parer" 0 0 0 "parka" 0 0 0
	"parry" 0 0 0 "parse" 0 0 0 "party" 0 0 0 "pasta" 0 0 0
	"pasty" 0 0 0 "patch" 0 0 0 "patio" 0 0 0 "patsy" 0 0 0
	"patty" 0 0 0 "pause" 0 0 0 "payee" 0 0 0 "peace" 0 0 0
	"peach" 0 0 0 "pearl" 0 0 0 "pedal" 0 0 0 "penal" 0 0 0
	"penny" 0 0 0 "perch" 0 0 0 "peril" 0 0 0 "pesky" 0 0 0
	"pesto" 0 0 0 "petal" 0 0 0 "petty" 0 0 0 "phase" 0 0 0
	"phone" 0 0 0 "phony" 0 0 0 "photo" 0 0 0 "piano" 0 0 0
	"picky" 0 0 0 "piece" 0 0 0 "pilot" 0 0 0 "pinch" 0 0 0
	"pinky" 0 0 0 "piper" 0 0 0 "pique" 0 0 0 "pitch" 0 0 0
	"pithy" 0 0 0 "pivot" 0 0 0 "pixel" 0 0 0 "pixie" 0 0 0
	"pizza" 0 0 0 "plaid" 0 0 0 "plain" 0 0 0 "plait" 0 0 0
	"plane" 0 0 0 "plank" 0 0 0 "plant" 0 0 0 "plate" 0 0 0
	"plaza" 0 0 0 "plead" 0 0 0 "pleat" 0 0 0 "plied" 0 0 0
	"plier" 0 0 0 "pluck" 0 0 0 "plumb" 0 0 0 "plume" 0 0 0
	"plump" 0 0 0 "plunk" 0 0 0 "plush" 0 0 0 "poesy" 0 0 0
	"point" 0 0 0 "poise" 0 0 0 "poker" 0 0 0 "polar" 0 0 0
	"polka" 0 0 0 "polyp" 0 0 0 "pooch" 0 0 0 "poppy" 0 0 0
	"porch" 0 0 0 "posit" 0 0 0 "posse" 0 0 0 "pouch" 0 0 0
	"pound" 0 0 0 "pouty" 0 0 0 "power" 0 0 0 "prank" 0 0 0
	"prawn" 0 0 0 "preen" 0 0 0 "press" 0 0 0 "price" 0 0 0
	"prick" 0 0 0 "pride" 0 0 0 "prime" 0 0 0 "primo" 0 0 0
	"print" 0 0 0 "prior" 0 0 0 "prism" 0 0 0 "privy" 0 0 0
	"prize" 0 0 0 "probe" 0 0 0 "prone" 0 0 0 "prong" 0 0 0
	"proof" 0 0 0 "prose" 0 0 0 "proud" 0 0 0 "prove" 0 0 0
	"prowl" 0 0 0 "proxy" 0 0 0 "prude" 0 0 0 "prune" 0 0 0
	"psalm" 0 0 0 "pubic" 0 0 0 "pudgy" 0 0 0 "puffy" 0 0 0
	"pulpy" 0 0 0 "pulse" 0 0 0 "pupal" 0 0 0 "pupil" 0 0 0
	"puree" 0 0 0 "purer" 0 0 0 "purge" 0 0 0 "pushy" 0 0 0
	"putty" 0 0 0 "pygmy" 0 0 0 "quake" 0 0 0 "qualm" 0 0 0
	"quart" 0 0 0 "quasi" 0 0 0 "queen" 0 0 0 "queer" 0 0 0
	"quell" 0 0 0 "query" 0 0 0 "queue" 0 0 0 "quiet" 0 0 0
	"quill" 0 0 0 "quilt" 0 0 0 "quirk" 0 0 0 "quota" 0 0 0
	"quoth" 0 0 0 "rabbi" 0 0 0 "rabid" 0 0 0 "racer" 0 0 0
	"radar" 0 0 0 "radii" 0 0 0 "radio" 0 0 0 "raise" 0 0 0
	"rally" 0 0 0 "ralph" 0 0 0 "ramen" 0 0 0 "ranch" 0 0 0
	"range" 0 0 0 "rapid" 0 0 0 "rarer" 0 0 0 "raspy" 0 0 0
	"ratty" 0 0 0 "raven" 0 0 0 "rayon" 0 0 0 "razor" 0 0 0
	"reach" 0 0 0 "react" 0 0 0 "ready" 0 0 0 "realm" 0 0 0
	"rebar" 0 0 0 "rebel" 0 0 0 "rebus" 0 0 0 "rebut" 0 0 0
	"recap" 0 0 0 "recur" 0 0 0 "recut" 0 0 0 "reedy" 0 0 0
	"refit" 0 0 0 "regal" 0 0 0 "rehab" 0 0 0 "reign" 0 0 0
	"relax" 0 0 0 "relay" 0 0 0 "remit" 0 0 0 "renal" 0 0 0
	"renew" 0 0 0 "repay" 0 0 0 "reply" 0 0 0 "rerun" 0 0 0
	"reset" 0 0 0 "retch" 0 0 0 "retro" 0 0 0 "retry" 0 0 0
	"reuse" 0 0 0 "revel" 0 0 0 "revue" 0 0 0 "rhino" 0 0 0
	"rhyme" 0 0 0 "rider" 0 0 0 "ridge" 0 0 0 "rifle" 0 0 0
	"right" 0 0 0 "rigid" 0 0 0 "rigor" 0 0 0 "rinse" 0 0 0
	"ripen" 0 0 0 "riper" 0 0 0 "risen" 0 0 0 "riser" 0 0 0
	"risky" 0 0 0 "rival" 0 0 0 "river" 0 0 0 "rivet" 0 0 0
	"roach" 0 0 0 "roast" 0 0 0 "robin" 0 0 0 "robot" 0 0 0
	"rocky" 0 0 0 "roger" 0 0 0 "rogue" 0 0 0 "roomy" 0 0 0
	"roost" 0 0 0 "rotor" 0 0 0 "rouge" 0 0 0 "rough" 0 0 0
	"round" 0 0 0 "rouse" 0 0 0 "route" 0 0 0 "rover" 0 0 0
	"rowdy" 0 0 0 "rower" 0 0 0 "royal" 0 0 0 "ruder" 0 0 0
	"rugby" 0 0 0 "ruler" 0 0 0 "rupee" 0 0 0 "rusty" 0 0 0
	"sadly" 0 0 0 "safer" 0 0 0 "saint" 0 0 0 "sally" 0 0 0
	"salon" 0 0 0 "salsa" 0 0 0 "salty" 0 0 0 "salve" 0 0 0
	"salvo" 0 0 0 "sandy" 0 0 0 "saner" 0 0 0 "sassy" 0 0 0
	"satin" 0 0 0 "satyr" 0 0 0 "sauce" 0 0 0 "saucy" 0 0 0
	"sauna" 0 0 0 "saute" 0 0 0 "savor" 0 0 0 "savoy" 0 0 0
	"savvy" 0 0 0 "scald" 0 0 0 "scale" 0 0 0 "scalp" 0 0 0
	"scaly" 0 0 0 "scamp" 0 0 0 "scant" 0 0 0 "scare" 0 0 0
	"scarf" 0 0 0 "scary" 0 0 0 "scene" 0 0 0 "scent" 0 0 0
	"scion" 0 0 0 "scoff" 0 0 0 "scold" 0 0 0 "scone" 0 0 0
	"scoop" 0 0 0 "scope" 0 0 0 "score" 0 0 0 "scorn" 0 0 0
	"scour" 0 0 0 "scout" 0 0 0 "scowl" 0 0 0 "scram" 0 0 0
	"scrap" 0 0 0 "scree" 0 0 0 "screw" 0 0 0 "scrub" 0 0 0
	"scrum" 0 0 0 "scuba" 0 0 0 "sedan" 0 0 0 "seize" 0 0 0
	"semen" 0 0 0 "sense" 0 0 0 "sepia" 0 0 0 "serve" 0 0 0
	"seven" 0 0 0 "sever" 0 0 0 "sewer" 0 0 0 "shack" 0 0 0
	"shade" 0 0 0 "shaft" 0 0 0 "shake" 0 0 0 "shaky" 0 0 0
	"shale" 0 0 0 "shall" 0 0 0 "shalt" 0 0 0 "shame" 0 0 0
	"shank" 0 0 0 "shape" 0 0 0 "shard" 0 0 0 "shark" 0 0 0
	"sharp" 0 0 0 "shave" 0 0 0 "shawl" 0 0 0 "shear" 0 0 0
	"sheen" 0 0 0 "sheep" 0 0 0 "sheet" 0 0 0 "sheik" 0 0 0
	"shelf" 0 0 0 "shell" 0 0 0 "shied" 0 0 0 "shine" 0 0 0
	"shiny" 0 0 0 "shire" 0 0 0 "shirk" 0 0 0 "shirt" 0 0 0
	"shoal" 0 0 0 "shock" 0 0 0 "shone" 0 0 0 "shook" 0 0 0
	"shoot" 0 0 0 "shore" 0 0 0 "shorn" 0 0 0 "short" 0 0 0
	"shout" 0 0 0 "shove" 0 0 0 "shown" 0 0 0 "showy" 0 0 0
	"shrub" 0 0 0 "shrug" 0 0 0 "shuck" 0 0 0 "shunt" 0 0 0
	"shush" 0 0 0 "sieve" 0 0 0 "sight" 0 0 0 "sigma" 0 0 0
	"silky" 0 0 0 "silly" 0 0 0 "since" 0 0 0 "sinew" 0 0 0
	"singe" 0 0 0 "siren" 0 0 0 "sissy" 0 0 0 "sixth" 0 0 0
	"sixty" 0 0 0 "skate" 0 0 0 "skier" 0 0 0 "skiff" 0 0 0
	"skill" 0 0 0 "skimp" 0 0 0 "skirt" 0 0 0 "skulk" 0 0 0
	"skull" 0 0 0 "slack" 0 0 0 "slain" 0 0 0 "slang" 0 0 0
	"slant" 0 0 0 "slash" 0 0 0 "slate" 0 0 0 "sleek" 0 0 0
	"sleep" 0 0 0 "sleet" 0 0 0 "slept" 0 0 0 "slide" 0 0 0
	"slime" 0 0 0 "slimy" 0 0 0 "slink" 0 0 0 "sloop" 0 0 0
	"slosh" 0 0 0 "slump" 0 0 0 "slung" 0 0 0 "slunk" 0 0 0
	"slurp" 0 0 0 "slyly" 0 0 0 "smack" 0 0 0 "small" 0 0 0
	"smart" 0 0 0 "smash" 0 0 0 "smear" 0 0 0 "smell" 0 0 0
	"smelt" 0 0 0 "smile" 0 0 0 "smirk" 0 0 0 "smite" 0 0 0
	"smith" 0 0 0 "smock" 0 0 0 "smoke" 0 0 0 "smote" 0 0 0
	"snack" 0 0 0 "snail" 0 0 0 "snake" 0 0 0 "snaky" 0 0 0
	"snare" 0 0 0 "snarl" 0 0 0 "sneak" 0 0 0 "sneer" 0 0 0
	"snide" 0 0 0 "sniff" 0 0 0 "snipe" 0 0 0 "snoop" 0 0 0
	"snort" 0 0 0 "snuck" 0 0 0 "snuff" 0 0 0 "soapy" 0 0 0
	"sober" 0 0 0 "soggy" 0 0 0 "solar" 0 0 0 "solid" 0 0 0
	"sonar" 0 0 0 "sonic" 0 0 0 "sooth" 0 0 0 "sooty" 0 0 0
	"sorry" 0 0 0 "sound" 0 0 0 "south" 0 0 0 "sower" 0 0 0
	"space" 0 0 0 "spade" 0 0 0 "spank" 0 0 0 "spare" 0 0 0
	"spark" 0 0 0 "spasm" 0 0 0 "spawn" 0 0 0 "speak" 0 0 0
	"spear" 0 0 0 "speck" 0 0 0 "speed" 0 0 0 "spell" 0 0 0
	"spelt" 0 0 0 "spent" 0 0 0 "sperm" 0 0 0 "spicy" 0 0 0
	"spiel" 0 0 0 "spike" 0 0 0 "spiky" 0 0 0 "spill" 0 0 0
	"spilt" 0 0 0 "spine" 0 0 0 "spiny" 0 0 0 "spire" 0 0 0
	"spite" 0 0 0 "splat" 0 0 0 "split" 0 0 0 "spoil" 0 0 0
	"spoke" 0 0 0 "spoof" 0 0 0 "spook" 0 0 0 "spoon" 0 0 0
	"spore" 0 0 0 "sport" 0 0 0 "spout" 0 0 0 "spray" 0 0 0
	"sprig" 0 0 0 "spunk" 0 0 0 "spurn" 0 0 0 "spurt" 0 0 0
	"squad" 0 0 0 "squat" 0 0 0 "squib" 0 0 0 "stack" 0 0 0
	"stage" 0 0 0 "staid" 0 0 0 "stain" 0 0 0 "stair" 0 0 0
	"stake" 0 0 0 "stale" 0 0 0 "stalk" 0 0 0 "stall" 0 0 0
	"stamp" 0 0 0 "stand" 0 0 0 "stank" 0 0 0 "stare" 0 0 0
	"stark" 0 0 0 "start" 0 0 0 "stash" 0 0 0 "state" 0 0 0
	"stave" 0 0 0 "steak" 0 0 0 "steal" 0 0 0 "steam" 0 0 0
	"steed" 0 0 0 "steel" 0 0 0 "steep" 0 0 0 "steer" 0 0 0
	"stein" 0 0 0 "stern" 0 0 0 "stick" 0 0 0 "stiff" 0 0 0
	"still" 0 0 0 "stilt" 0 0 0 "sting" 0 0 0 "stink" 0 0 0
	"stint" 0 0 0 "stock" 0 0 0 "stoic" 0 0 0 "stoke" 0 0 0
	"stole" 0 0 0 "stomp" 0 0 0 "stone" 0 0 0 "stony" 0 0 0
	"stood" 0 0 0 "stool" 0 0 0 "stoop" 0 0 0 "store" 0 0 0
	"stork" 0 0 0 "storm" 0 0 0 "story" 0 0 0 "stove" 0 0 0
	"strap" 0 0 0 "straw" 0 0 0 "stray" 0 0 0 "strip" 0 0 0
	"strut" 0 0 0 "stuck" 0 0 0 "study" 0 0 0 "stump" 0 0 0
	"stunt" 0 0 0 "style" 0 0 0 "suave" 0 0 0 "sugar" 0 0 0
	"suing" 0 0 0 "suite" 0 0 0 "sulky" 0 0 0 "sully" 0 0 0
	"sumac" 0 0 0 "sunny" 0 0 0 "super" 0 0 0 "surer" 0 0 0
	"surge" 0 0 0 "surly" 0 0 0 "sushi" 0 0 0 "swami" 0 0 0
	"swamp" 0 0 0 "swash" 0 0 0 "swath" 0 0 0 "swear" 0 0 0
	"sweat" 0 0 0 "sweet" 0 0 0 "swell" 0 0 0 "swept" 0 0 0
	"swift" 0 0 0 "swill" 0 0 0 "swine" 0 0 0 "swirl" 0 0 0
	"swish" 0 0 0 "swoon" 0 0 0 "sword" 0 0 0 "swore" 0 0 0
	"sworn" 0 0 0 "swung" 0 0 0 "synod" 0 0 0 "syrup" 0 0 0
	"tabby" 0 0 0 "table" 0 0 0 "taboo" 0 0 0 "tacit" 0 0 0
	"taffy" 0 0 0 "taint" 0 0 0 "taker" 0 0 0 "tally" 0 0 0
	"taper" 0 0 0 "tapir" 0 0 0 "tardy" 0 0 0 "tarot" 0 0 0
	"taste" 0 0 0 "tasty" 0 0 0 "tatty" 0 0 0 "taunt" 0 0 0
	"tawny" 0 0 0 "teach" 0 0 0 "teary" 0 0 0 "tease" 0 0 0
	"teddy" 0 0 0 "teeth" 0 0 0 "tempo" 0 0 0 "tenet" 0 0 0
	"tenor" 0 0 0 "tense" 0 0 0 "tenth" 0 0 0 "tepee" 0 0 0
	"tepid" 0 0 0 "terra" 0 0 0 "terse" 0 0 0 "testy" 0 0 0
	"thank" 0 0 0 "theft" 0 0 0 "their" 0 0 0 "theme" 0 0 0
	"there" 0 0 0 "these" 0 0 0 "theta" 0 0 0 "thick" 0 0 0
	"thief" 0 0 0 "thigh" 0 0 0 "thing" 0 0 0 "think" 0 0 0
	"third" 0 0 0 "thong" 0 0 0 "thorn" 0 0 0 "those" 0 0 0
	"three" 0 0 0 "threw" 0 0 0 "throb" 0 0 0 "throw" 0 0 0
	"thrum" 0 0 0 "thumb" 0 0 0 "thump" 0 0 0 "thyme" 0 0 0
	"tiara" 0 0 0 "tibia" 0 0 0 "tidal" 0 0 0 "tiger" 0 0 0
	"tight" 0 0 0 "tilde" 0 0 0 "timid" 0 0 0 "tipsy" 0 0 0
	"titan" 0 0 0 "tithe" 0 0 0 "title" 0 0 0 "toast" 0 0 0
	"today" 0 0 0 "toddy" 0 0 0 "token" 0 0 0 "tonal" 0 0 0
	"tonga" 0 0 0 "tonic" 0 0 0 "tooth" 0 0 0 "topaz" 0 0 0
	"topic" 0 0 0 "torch" 0 0 0 "torso" 0 0 0 "torus" 0 0 0
	"total" 0 0 0 "touch" 0 0 0 "tough" 0 0 0 "towel" 0 0 0
	"tower" 0 0 0 "toxin" 0 0 0 "trace" 0 0 0 "track" 0 0 0
	"tract" 0 0 0 "trait" 0 0 0 "trawl" 0 0 0 "tread" 0 0 0
	"treat" 0 0 0 "trend" 0 0 0 "triad" 0 0 0 "trial" 0 0 0
	"tribe" 0 0 0 "trice" 0 0 0 "trick" 0 0 0 "tried" 0 0 0
	"tripe" 0 0 0 "trite" 0 0 0 "troll" 0 0 0 "troop" 0 0 0
	"trope" 0 0 0 "trout" 0 0 0 "trove" 0 0 0 "truce" 0 0 0
	"truck" 0 0 0 "truer" 0 0 0 "truly" 0 0 0 "trump" 0 0 0
	"trunk" 0 0 0 "trust" 0 0 0 "truth" 0 0 0 "tryst" 0 0 0
	"tuber" 0 0 0 "tulip" 0 0 0 "tulle" 0 0 0 "tumor" 0 0 0
	"tunic" 0 0 0 "tutor" 0 0 0 "twang" 0 0 0 "tweak" 0 0 0
	"tweed" 0 0 0 "tweet" 0 0 0 "twice" 0 0 0 "twink" 0 0 0
	"twirl" 0 0 0 "twist" 0 0 0 "twixt" 0 0 0 "tying" 0 0 0
	"udder" 0 0 0 "ulcer" 0 0 0 "ultra" 0 0 0 "umbra" 0 0 0
	"uncle" 0 0 0 "uncut" 0 0 0 "under" 0 0 0 "undid" 0 0 0
	"undue" 0 0 0 "unfed" 0 0 0 "unify" 0 0 0 "union" 0 0 0
	"unite" 0 0 0 "unity" 0 0 0 "unmet" 0 0 0 "unset" 0 0 0
	"untie" 0 0 0 "until" 0 0 0 "unwed" 0 0 0 "unzip" 0 0 0
	"upper" 0 0 0 "upset" 0 0 0 "urban" 0 0 0 "urine" 0 0 0
	"usage" 0 0 0 "usher" 0 0 0 "usual" 0 0 0 "usurp" 0 0 0
	"utile" 0 0 0 "utter" 0 0 0 "vague" 0 0 0 "valet" 0 0 0
	"valid" 0 0 0 "valor" 0 0 0 "value" 0 0 0 "valve" 0 0 0
	"vapid" 0 0 0 "vapor" 0 0 0 "vaunt" 0 0 0 "vegan" 0 0 0
	"venom" 0 0 0 "venue" 0 0 0 "verge" 0 0 0 "verse" 0 0 0
	"verso" 0 0 0 "verve" 0 0 0 "vicar" 0 0 0 "video" 0 0 0
	"vigil" 0 0 0 "vigor" 0 0 0 "villa" 0 0 0 "vinyl" 0 0 0
	"viola" 0 0 0 "viral" 0 0 0 "virus" 0 0 0 "visit" 0 0 0
	"visor" 0 0 0 "vista" 0 0 0 "vital" 0 0 0 "vivid" 0 0 0
	"vixen" 0 0 0 "vocal" 0 0 0 "vodka" 0 0 0 "vogue" 0 0 0
	"voice" 0 0 0 "voila" 0 0 0 "vomit" 0 0 0 "voter" 0 0 0
	"vowel" 0 0 0 "vying" 0 0 0 "wacky" 0 0 0 "wafer" 0 0 0
	"wager" 0 0 0 "waist" 0 0 0 "waive" 0 0 0 "waltz" 0 0 0
	"warty" 0 0 0 "waste" 0 0 0 "watch" 0 0 0 "water" 0 0 0
	"waver" 0 0 0 "waxen" 0 0 0 "weave" 0 0 0 "wedge" 0 0 0
	"weedy" 0 0 0 "welch" 0 0 0 "welsh" 0 0 0 "wench" 0 0 0
	"whack" 0 0 0 "whale" 0 0 0 "wharf" 0 0 0 "wheat" 0 0 0
	"wheel" 0 0 0 "whelp" 0 0 0 "where" 0 0 0 "which" 0 0 0
	"whiff" 0 0 0 "whine" 0 0 0 "whiny" 0 0 0 "whirl" 0 0 0
	"whisk" 0 0 0 "white" 0 0 0 "whole" 0 0 0 "whose" 0 0 0
	"widen" 0 0 0 "wider" 0 0 0 "widow" 0 0 0 "width" 0 0 0
	"wield" 0 0 0 "willy" 0 0 0 "wimpy" 0 0 0 "wince" 0 0 0
	"winch" 0 0 0 "windy" 0 0 0 "wiser" 0 0 0 "wispy" 0 0 0
	"witch" 0 0 0 "witty" 0 0 0 "woken" 0 0 0 "woman" 0 0 0
	"women" 0 0 0 "woody" 0 0 0 "wooer" 0 0 0 "wooly" 0 0 0
	"woozy" 0 0 0 "world" 0 0 0 "worry" 0 0 0 "worse" 0 0 0
	"worst" 0 0 0 "worth" 0 0 0 "would" 0 0 0 "wound" 0 0 0
	"woven" 0 0 0 "wrack" 0 0 0 "wrath" 0 0 0 "wreak" 0 0 0
	"wreck" 0 0 0 "wrest" 0 0 0 "wrist" 0 0 0 "write" 0 0 0
	"wrong" 0 0 0 "wrote" 0 0 0 "wrung" 0 0 0 "wryly" 0 0 0
	"yacht" 0 0 0 "yearn" 0 0 0 "yield" 0 0 0 "young" 0 0 0
	"youth" 0 0 0 "zebra" 0 0 0 "zesty" 0 0 0 "zonal" 0 0 0
