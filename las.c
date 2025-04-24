#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>
#include <stdio.h>

typedef enum Type {
	END,
	SREG,
	LREG,
	INST,
	NUMBER,
	STRING,
	LABEL,
	MACRO,
	SOURCE,
	STMT,
} Type;

typedef struct Place {
	char *name;
	int line;
} Place;

typedef struct Chunk {
	struct Chunk *next;
	enum Type type;
	int size, offset;
	Place place;
	union {
		struct {
			union {
				unsigned opc;
				void (*emit)(FILE *, struct Chunk *);
			};
			unsigned isref, isreg;
			unsigned *label, base, arg;
		};
		unsigned number;
		char *string;
		struct Chunk *source;
	};
} Chunk;

typedef struct Label {
	struct Label *less, *more;
	char *name;
	unsigned value, defined;
} Label;

typedef struct Code {
	char *name;
	unsigned code;
} Code;

typedef struct Macro {
	char *name;
	int size;
	void (*emit)(FILE *, Chunk *);
} Macro;

typedef struct Scan {
	FILE *f;
	Place place;
	int type;
	char token[128];
	union {
		Macro *macro;
		Label *label;
		int value;
	};
} Scan;

int numlen(unsigned num);
unsigned tonum(char *s);
Chunk *parseinst(Scan *sc);
Chunk *parsemacro(Scan *sc);
Chunk *parsenumber(Scan *sc);
Chunk *parsestring(Scan *sc);
Chunk *parselabel(Scan *sc);
Chunk *parsesource(Scan *sc);
Chunk *parseoffset(Scan *sc);

/* TODO: what if instead of chunk type
   there'd be just emitter pointer?
*/
void emit(FILE *, Chunk *);
void emitinst(FILE *, Chunk *);
void emitnumber(FILE *, Chunk *);
void emitstring(FILE *, Chunk *);
void emitldb(FILE *, Chunk *);
void emitj(FILE *, Chunk *);
void emitjc(FILE *, Chunk *);
void emitsj(FILE *, Chunk *);
void emitsjc(FILE *, Chunk *);
void emitlld(FILE *, Chunk *);
void emitldh(FILE *, Chunk *);
void emitsld(FILE *, Chunk *);
void emitsst(FILE *, Chunk *);
void emitcall(FILE *, Chunk *);
void emitpshb(FILE *, Chunk *);
void emitpopb(FILE *, Chunk *);
void emitpshm(FILE *, Chunk *);
void emitpopm(FILE *, Chunk *);
void emitret(FILE *, Chunk *);

char *tokens[] = {
	[END]    "end of file",
	[LREG]   "base register",
	[SREG]   "short register",
	[INST]   "instruction name",
	[STRING] "string",
	[LABEL]  "label",
	[NUMBER] "number",
	[MACRO]  "macroinstruction name",
	[STMT]   "statement",
	['\n']   "new line",
	[',']    "','",
	[':']    "':'",
	['#']    "'#'",
	['+']    "'+'",
};

Code sregs[] = {
	{"a",  0x0000},
	{"bl", 0x0001},
	{"bh", 0x0002},
	{"sl", 0x0003},
	{0, -1},
};

Code lregs[] = {
	{"b",  0x400},
	{"pc", 0x800},
	{"sp", 0xc00},
	{0, -1},
};

Code ops[] = {
	{"ld",  0x4000},
	{"st",  0x5000},

	{"jmp", 0x6000},
	{"jmc", 0x7000},

	{"jal", 0x8400},
	{"rti", 0x8800},
	{"psh", 0x8c00},
	{"pop", 0x9200},
	{"hlt", 0x9400},

	{"inc", 0xa000},
	{"dec", 0xa400},
	{"obt", 0xac00},

	{"add", 0xc000},
	{"adc", 0xc400},
	{"sub", 0xc800},
	{"suc", 0xcc00},
	{"shl", 0xd000},
	{"shr", 0xd400},
	{"and", 0xd800},
	{"or",  0xdc00},
	{"xor", 0xe000},

	{"stc", 0xe400},
	{"tne", 0xe800},
	{"tlt", 0xec00},
	{"tgt", 0xf000},
	{"tle", 0xf400},
	{"tge", 0xf800},
	{"teq", 0xfc00},
	{0, -1},
};

Macro macros[] = {
	{"ldb",  4*2, emitldb},
	{"j",    5*2, emitj},
	{"jc",   5*2, emitjc},
	{"sj",     2, emitsj},
	{"sjc",    2, emitsjc},
	{"lld",  5*2, emitlld},
	{"ldh",    2, emitldh},
	{"sld",    2, emitsld},
	{"sst",    2, emitsst},
	{"call", 5*2, emitcall},
	{"pshb", 2*2, emitpshb},
	{"popb", 2*2, emitpopb},
	{"pshm", 2*2, emitpshm},
	{"popm", 2*2, emitpopm},
	{"ret",  3*2, emitret},
	{0},
};

Code stmts[] = {
	{"include", 0},
	{"offset",  0},
	{0, -1},
};

char escape[] = {
	['0']  '\0',
	['a']  '\a',
	['b']  '\b',
	['e']  '\e',
	['f']  '\f',
	['n']  '\n',
	['r']  '\r',
	['t']  '\t',
	['v']  '\v',
	['a']  '\a',
	['\\'] '\\',
	['\''] '\'',
	['\"'] '\"',
};

int flag_verbose = 0;

unsigned offset = 0x200;
Label *labels = 0;

int errorf(Place *p, const char *fmt, ...)
{
	int n;
	va_list args;

	va_start(args, fmt);
	fprintf(stderr, "error: ");
	if (p)
		fprintf(stderr, "%s: %d: ", p->name, p->line);
	n = vfprintf(stderr, fmt, args);
	va_end(args);

	return n;
}

int warnf(Place *p, const char *fmt, ...)
{
	int n;
	va_list args;

	va_start(args, fmt);
	fprintf(stderr, "warning: ");
	if (p)
		fprintf(stderr, "%s: %d: ", p->name, p->line);
	n = vfprintf(stderr, fmt, args);
	va_end(args);

	return n;
}

int find(Code vec[], char *key)
{
	int i;

	for (i = 0; vec[i].name; i++)
	    if (strcmp(vec[i].name, key) == 0)
	        return vec[i].code;
	return -1;
}

Macro *findmacro(Macro vec[], char *key)
{
	int i;

	for (i = 0; vec[i].name; i++)
	    if (strcmp(vec[i].name, key) == 0)
	        return &vec[i];
	return 0;
}

char *dupl(char *s)
{
	char *d = calloc(strlen(s)+1, sizeof(*d));

	return strcpy(d, s);
}

Label *deflabel(Label *l, char *s)
{
	int c;

	if (!l) {
		l = calloc(1, sizeof(*l));
		l->name = dupl(s);
		return l;
	}
	c = strcmp(s, l->name);
	if (c > 0)
		l->more = deflabel(l->more, s);
	else if (c < 0)
		l->less = deflabel(l->less, s);
	return l;
}

Label *getlabel(Label *l, char *s)
{
	int c;

	c = strcmp(s, l->name);
	if (c > 0)
		return getlabel(l->more, s);
	else if (c < 0)
		return getlabel(l->less, s);
	return l;
}

int checklabel(Label *l)
{
	int ok = 1;

	ok &= l->defined;
	if (l->less)
		ok &= checklabel(l->less);
	if (!l->defined)
		errorf(0, "undefined label: %s\n", l->name);
	if (l->more)
		ok &= checklabel(l->more);
	return ok;
}

Type scan(Scan *sc)
{
	static char *spec = "=:#+\n";
	FILE *f = sc->f;
	int i, ch, quote = '\0';

	/* skip comments and whitespace */
	while (isspace(ch = fgetc(f)) && ch != '\n')
		;
	if (ch == ';') {
		while ((ch = fgetc(f)) != '\n')
			;
	} else if (ch < 0) {
		return sc->type = END;
	}

	/* read token */
	i = 0;
	sc->token[i++] = ch;
	if (ch == '\"' || ch == '\'') {
		quote = ch;
		i = 0;
		while ((ch = fgetc(f)) != quote) {
			if (ch == '\\')
				ch = escape[fgetc(f)];
			sc->token[i++] = ch;
		}
	} else if (!strchr(spec, ch)) {
		while (!isspace(ch = fgetc(f)) && !strchr(spec, ch))
			sc->token[i++] = ch;
		ungetc(ch, f);
	}
	sc->token[i] = '\0';

	if (sc->token[0] == '\n')
		sc->place.line++;

	/* classify */
	if (quote == '\0' && strchr(spec, sc->token[0])) {
		sc->value = sc->type = ch;
	} else if ((sc->value = find(lregs, sc->token)) >=0) {
		sc->type = LREG;
	} else if ((sc->value = find(sregs, sc->token)) >= 0) {
		sc->type = SREG;
	} else if ((sc->value = find(ops, sc->token)) >= 0) {
		sc->type = INST;
	} else if ((find(stmts, sc->token) >= 0)) {
		sc->type = STMT;
	} else if ((sc->macro = findmacro(macros, sc->token))) {
		sc->type = MACRO;
	} else if (quote == '\"') {
		sc->type = STRING;
	} else if (quote == '\'') {
		sc->value = sc->token[0];
		sc->type = NUMBER;
	} else if (isdigit(sc->token[0])) {
		sc->value = tonum(sc->token);
		sc->type = NUMBER;
	} else {
		labels = deflabel(labels, sc->token);
		sc->label = getlabel(labels, sc->token);
		sc->type = LABEL;
	}
	return sc->type;
}

int consume(Scan *sc, Type t)
{
	if (sc->type != t)
		return 0;
	scan(sc);
	return 1;
}

int expect(Scan *sc, Type t)
{
	if (consume(sc, t))
		return 1;
	errorf(&sc->place, "expected: %s, got: %s\n", tokens[t], tokens[sc->type]);
	exit(1);
}

int numlen(unsigned num)
{
	int n = 0;

	if (num == 0)
		return 1;
	while (num != 0) {
		num >>= 8;
		n++;
	}
	return n;
}

unsigned tonum(char *s)
{
	int i, n = strlen(s);
	int num = 0, d;
	int base;

	switch (s[n-1]) {
	case 'b':
		base = 2;
		n--;
		break;
	case 'o':
		base = 8;
		n--;
		break;
	case 'h':
		base = 16;
		n--;
		break;
	default: /* assume decimal */
		base = 10;
		break;
	}

	for (i = 0; i < n; i++) {
		d = isdigit(s[i])? s[i] - '0' : s[i] - 'a' + 10;
		num = num*base + d;
	}

	return num;
}

Chunk *parse(FILE *f, char *name)
{
	Chunk *head = 0, *tail, *ck;
	Place place;
	Scan sc = {.f = f, { name, 1 } };

	scan(&sc);

	while (sc.type != END) {
		place = sc.place;
		switch (sc.type) {
		default:
			errorf(&sc.place, "unexpected token: %s (%s)\n",
				tokens[sc.type], sc.token);
			exit(1);
		case INST:
			if (offset & 1) {
				errorf(&sc.place, "instruction at an odd address: %04xh\n", offset);
				exit(1);
			}
			ck = parseinst(&sc);
			break;
		case MACRO:
			ck = parsemacro(&sc);
			break;
		case NUMBER:
			ck = parsenumber(&sc);
			break;
		case STRING:
			ck = parsestring(&sc);
			break;
		case STMT:
			ck = 0;
			if (strcmp(sc.token, "include") == 0)
				ck = parsesource(&sc);
			if (strcmp(sc.token, "offset") == 0)
				ck = parseoffset(&sc);
			break;
		case LABEL:
			ck = parselabel(&sc);
			break;
		case END:
			ck = 0;
			break;
		case '\n':
			consume(&sc, '\n');
			ck = 0;
			break;
		}
		if (ck) {
			ck->place = place;
			ck->offset = offset;
			offset += ck->size;
			if (!head)
				head = ck;
			else
				tail->next = ck;
			tail = ck;
		}
	}

	return head;
}

void parsearg(Scan *sc, Chunk *ck)
{
	if (sc->type == '#') {
		ck->isref = 1;
		expect(sc, '#');
	}
	if (sc->type == LREG) {
		ck->base = sc->value;
		expect(sc, LREG);
		if (!consume(sc, '+'))
			ck->arg = 0;
	}
	if (sc->type == SREG) {
		ck->isreg = 1;
		ck->arg = sc->value;
		expect(sc, SREG);
	} else if (sc->type == NUMBER) {
		ck->arg = sc->value;
		expect(sc, NUMBER);
	} else if (sc->type == LABEL) {
		ck->label = &sc->label->value;
		expect(sc, LABEL);
	}
}

Chunk *parseinst(Scan *sc)
{
	Chunk *ck = calloc(1, sizeof(*ck));

	ck->type = INST;
	ck->size = 2;
	ck->opc = sc->value;

	expect(sc, INST);
	parsearg(sc, ck);
	consume(sc, '\n');
	return ck;
}

Chunk *parsemacro(Scan *sc)
{
	Chunk *ck = calloc(1, sizeof(*ck));

	ck->type = MACRO;
	ck->size = sc->macro->size;
	ck->emit = sc->macro->emit;

	expect(sc, MACRO);
	parsearg(sc, ck);
	consume(sc, '\n');
	return ck;
}

Chunk *parsenumber(Scan *sc)
{
	Chunk *ck = calloc(1, sizeof(*ck));

	ck->type = NUMBER;
	ck->size = numlen(sc->value);
	ck->number = sc->value;
	expect(sc, NUMBER);

	return ck;
}

Chunk *parsestring(Scan *sc)
{
	Chunk *ck = calloc(1, sizeof(*ck));

	ck->type = STRING;
	ck->size = strlen(sc->token);
	ck->string = dupl(sc->token);
	expect(sc, STRING);

	return ck;
}

Chunk *parselabel(Scan *sc)
{
	Label *label = sc->label;

	if (flag_verbose)
		fprintf(stderr, "%s = ", sc->token);

	expect(sc, LABEL);

	if (consume(sc, '=')) {
		label->value = sc->value;
		label->defined = 1;
		expect(sc, NUMBER);
	} else if (expect(sc, ':')) {
		label->value = offset;
		label->defined = 1;
	}

	if (flag_verbose)
		fprintf(stderr, "%04x\n", label->value);

	return 0;
}

Chunk *parsesource(Scan *sc)
{
	Chunk *ck = calloc(1, sizeof(*ck));
	FILE *f;
	char *name;

	expect(sc, STMT);

	name = dupl(sc->token);
	f = fopen(name, "r");
	if (!f)
		errorf(&sc->place, "could not open file: %s\n", sc->token);
	expect(sc, STRING);

	ck->type = SOURCE;
	ck->size = 0;
	ck->source = parse(f, name);
	fclose(f);

	return ck;
}

Chunk *parseoffset(Scan *sc)
{
	Chunk *ck = calloc(1, sizeof(*ck));

	expect(sc, STMT);
	offset = sc->value;
	expect(sc, NUMBER);

	return 0;
}

void emitinst(FILE *f, Chunk *ck)
{
	unsigned code = 0;

	code |= ck->isref << 9;
	code |= ck->isreg << 8;
	code |= ck->opc;
	code |= ck->base;
	code |= ck->arg & 0xff;

	fputc((code >> 8) & 0xff, f);
	fputc((code >> 0) & 0xff, f);
}

void emitnumber(FILE *f, Chunk *ck)
{
	int n = ck->size;
	int number = ck->number;

	while (n-- > 0) {
		fputc(number & 0xff, f);
		number >>= 8;
	}
}

void emitstring(FILE *f, Chunk *ck)
{
	char *ch = ck->string;

	while (*ch)
		fputc(*ch++, f);
}

void emitsource(FILE *f, Chunk *ck)
{
	for (ck = ck->source; ck; ck = ck->next)
		emit(f, ck);
}

void emitldb(FILE *f, Chunk *ck)
{
	Chunk c;

	c.base = 0;
	c.isref = 0;

	if (ck->isref || ck->isreg)
		errorf(&ck->place, "ldb instruction works only with constants\n");

	c.opc = find(ops, "ld");
	c.isreg = 0;
	c.arg = ck->arg & 0xff;
	emitinst(f, &c);

	c.opc = find(ops, "st");
	c.isreg = 1;
	c.arg = find(sregs, "bl");
	emitinst(f, &c);

	c.opc = find(ops, "ld");
	c.isreg = 0;
	c.arg = (ck->arg >> 8) & 0xff;
	emitinst(f, &c);

	c.opc = find(ops, "st");
	c.isreg = 1;
	c.arg = find(sregs, "bh");
	emitinst(f, &c);
}

void emitbased(FILE *f, Chunk *ck, char *op)
{
	Chunk c;

	emitldb(f, ck);

	c.opc = find(ops, op);
	c.base = find(lregs, "b");
	c.isref = 0;
	c.isreg = 0;
	c.arg = 0;
	emitinst(f, &c);
}

void emitcall(FILE *f, Chunk *ck)
{
	emitbased(f, ck, "jal");
}

void emitj(FILE *f, Chunk *ck)
{
	int diff = 128 + ck->arg - ck->offset;

	if (diff >= 0 && diff <= 255)
		warnf(&ck->place, "jump to nearby address: suggest using sj\n");
	emitbased(f, ck, "jmp");
}

void emitjc(FILE *f, Chunk *ck)
{
	int diff = 128 + ck->arg - ck->offset;

	if (diff >= 0 && diff <= 255)
		warnf(&ck->place, "jump to nearby address: suggest using sjc\n");
	emitbased(f, ck, "jmc");
}

void emitrel(FILE *f, Chunk *ck, char *op)
{
	int diff = 128 + ck->arg - ck->offset;
	Chunk c;

	if (ck->isreg)
		errorf(&ck->place, "relative addressing with constant, missing '#'?\n");
	if (diff < 0)
		errorf(&ck->place, "relative addressing below -128\n");
	if (diff > 255)
		errorf(&ck->place, "relative addressing above +127\n");

	c.opc = find(ops, op);
	c.base = find(lregs, "pc");
	c.isref = ck->isref;
	c.isreg = 0;
	c.arg = diff;
	emitinst(f, &c);
}

void emitsj(FILE *f, Chunk *ck)
{
	emitrel(f, ck, "jmp");
}

void emitsjc(FILE *f, Chunk *ck)
{
	emitrel(f, ck, "jmc");
}

void emitsld(FILE *f, Chunk *ck)
{
	emitrel(f, ck, "ld");
}

void emitsst(FILE *f, Chunk *ck)
{
	emitrel(f, ck, "st");
}

void emitlld(FILE *f, Chunk *ck)
{
	int diff = 128 + ck->arg - ck->offset;
	Chunk c;

	if (!ck->isref || ck->isreg)
		errorf(&ck->place, "lld instruction works only with addresses");
	if (diff >= 0 && diff <= 255)
		warnf(&ck->place, "load from nearby address: suggest using sld\n");

	c = *ck;
	c.isref = 0;
	emitldb(f, &c);

	c.opc = find(ops, "ld");
	c.base = find(lregs, "b");
	c.isref = 1;
	c.isreg = 0;
	c.arg = 0;
	emitinst(f, &c);
}

void emitldh(FILE *f, Chunk *ck)
{
	Chunk c;

	if (ck->base || ck->isref || ck->isreg)
		errorf(&ck->place, "ldh instruction works only with constants");

	c.base = 0;
	c.isref = 0;
	c.isreg = 0;
	c.opc = find(ops, "ld");
	c.arg = (ck->arg >> 8) & 0xff;

	emitinst(f, &c);
}

void emitret(FILE *f, Chunk *ck)
{
	Chunk c;

	emitpopb(f, ck);

	c.opc = find(ops, "jmp");
	c.base = find(lregs, "b");
	c.isref = 0;
	c.isreg = 0;
	c.label = 0;
	c.arg = 0;
	emitinst(f, &c);
}

void emitpshb(FILE *f, Chunk *ck)
{
	Chunk c;

	c.opc = find(ops, "psh");
	c.base = 0;
	c.isref = 0;
	c.isreg = 1;
	c.label = 0;
	c.arg = 0;

	c.arg = find(sregs, "bl");
	emitinst(f, &c);

	c.arg = find(sregs, "bh");
	emitinst(f, &c);
}

void emitpopb(FILE *f, Chunk *ck)
{
	Chunk c;

	c.opc = find(ops, "pop");
	c.base = 0;
	c.isref = 0;
	c.isreg = 0;
	c.label = 0;

	c.arg = find(sregs, "bh");
	emitinst(f, &c);

	c.arg = find(sregs, "bl");
	emitinst(f, &c);
}

void emitpshm(FILE *f, Chunk *ck)
{
	Chunk c;

	if (!ck->isref) {
		errorf(&ck->place, "pshm macro works only with references\n");
		exit(1);
	}

	c.opc = find(ops, "ld");
	c.base = ck->base;
	c.isref = ck->isref;
	c.isreg = ck->isreg;
	c.arg = ck->arg;
	emitinst(f, &c);

	c.opc = find(ops, "psh");
	c.base = 0;
	c.isref = 0;
	c.isreg = 1;
	c.arg = find(sregs, "a");
	emitinst(f, &c);
}

void emitpopm(FILE *f, Chunk *ck)
{
	Chunk c;

	if (!ck->isref) {
		errorf(&ck->place, "popm macro works only with references\n");
		exit(1);
	}

	c.opc = find(ops, "pop");
	c.base = 0;
	c.isref = 0;
	c.isreg = 1;
	c.arg = find(sregs, "a");
	emitinst(f, &c);

	c.opc = find(ops, "st");
	c.base = ck->base;
	c.isref = ck->isref;
	c.isreg = ck->isreg;
	c.arg = ck->arg;
	emitinst(f, &c);
}

void emit(FILE *f, Chunk *ck)
{
	if (ck->type == INST || ck->type == MACRO)
		if (ck->label)
			ck->arg = *ck->label;
	switch (ck->type) {
	case INST:
		return emitinst(f, ck);
	case MACRO:
		return ck->emit(f, ck);
	case NUMBER:
		return emitnumber(f, ck);
	case STRING:
		return emitstring(f, ck);
	case SOURCE:
		return emitsource(f, ck);
	default:
		errorf(&ck->place, "chunk type %d cannot be emitted", ck->type);
		exit(1);
	}
}

int main(int argc, char *argv[])
{
	int i;
	char *iname = 0, *oname = 0;
	FILE *input, *output;
	Chunk *ck;

	for (i = 1; i < argc; i++) {
		if (argv[i][0] != '-') {
			if (iname) {
				errorf(0, "only one input file allowed\n");
				exit(1);
			}
			iname = argv[i];
			continue;
		}
		if (argv[i][2] != '\0') {
			errorf(0, "only single character flags allowed\n");
			exit(1);
		}
		switch (argv[i][1]) {
		case 'o':
			if (!argv[i+1]) {
				errorf(0, "flag -o requires a filename argument\n");
				exit(1);
			}
			oname = argv[++i];
			break;
		case 'v':
			flag_verbose = 1;
			break;
		default:
			errorf(0, "unknown flag: %s\n", argv[i]);
			exit(1);
			break;
		}
	}

	if (!(input = fopen(iname, "r"))) {
		errorf(0, "could not open file: %s\n", iname);
		exit(1);
	}
	if (!(output = fopen(oname, "w+"))) {
		errorf(0, "could not open file: %s\n", oname);
		exit(1);
	}

	ck = parse(input, iname);
	if (!checklabel(labels))
		exit(1);
	for (; ck; ck = ck->next)
		emit(output, ck);

	return 0;
}
