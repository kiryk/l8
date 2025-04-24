#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/*
	FS maker for Toucan OS.
	Use: ./mkfs <output> [-d <dir> <filelist...>]

	     ./mkfs l8.img -d tools hello
			 -- moves hello from host to /tools on l8.img

	First byte of the FAT is the disk size in sectors

	FAT entries 00 mean free
	FAT entries ff mean last sector
	Otherwise they point to the next sector

	Folders are files with sequences of entries
	Empty entries point to ff
	Last empty entry points to 00
	Links have size == 0, but point to 01-fe
	There are no empty files

	Attributes are just tips for convenience,
	shouldn't mislead, but don't enforce any behavior on
	the FS driver.
*/

#define SECTOR_SZ 512
#define FAT_SZ 256

typedef unsigned char Byte;
typedef Byte Sector[SECTOR_SZ];
typedef Sector Disk[FAT_SZ-1];
typedef Byte File;

enum {
	ATTR_FOLDER = 0x01,
	ATTR_EXEC   = 0x02,

	ATTR_LINK   = 0x04,
};

typedef struct {
	char name[28];
	Byte size[2];
	Byte head;
	Byte attr;
} Entry;

Entry *find(Disk d, File dir, char *name);

int alloc(Disk d)
{
	Byte *fat = d[0];
	int i;

	for (i = 1; i < FAT_SZ; i++) {
		if (fat[i] == 0) {
			fat[i] = 0xff;
			return i;
		}
	}
	return -1;
}

void store(Disk d, Entry *e, FILE *f)
{
	int curr, prev = 0, size = 0;
	Byte *fat = d[0];

	while (!feof(f)) {
		curr = alloc(d);
		if (prev > 0)
			fat[prev] = curr;
		else
			e->head = curr;
		size += fread(d[curr], 1, SECTOR_SZ, f);
		prev = curr;
	}

	e->size[0] = (size >> 0) & 0xff;
	e->size[1] = (size >> 8) & 0xff;
}

Entry *mkfile(Disk d, File dir, char *name)
{
	int i;
	Entry *e = (Entry *)(&d[dir]);

	for (i = 0; i < SECTOR_SZ/sizeof(Entry); i++) {
		if (strcmp(e[i].name, name) == 0)
			fprintf(stderr, "error: file %s already exists\n", name);
		if (e[i].head == 0)
			break;
	}
	e[i].head = 0xff;
	e[i].size[0] = 0;
	e[i].size[1] = 0;
	strcpy(e[i].name, name);

	return &e[i];
}

Entry *mkdir(Disk d, File dir, char *name)
{
	Entry *e = mkfile(d, dir, name);
	Entry up;

	up.head = dir;
	up.size[0] = 0;
	up.size[1] = 0;
	up.attr |= ATTR_FOLDER;
	strcpy(up.name, "..");

	e->head = alloc(d);
	e->size[0] = 1;
	e->size[1] = 0;
	e->attr |= ATTR_FOLDER;
	strcpy(e->name, name);

	memset(d[e->head], 0, sizeof(up));
	memcpy(d[e->head], &up, sizeof(up));

	return e;
}

Entry *mkpath(Disk d, File dir, char *path)
{
	Entry *e;
	char *next;

	if ((next = strchr(path, '/')))
		*next++ = '\0';
	if (!(e = find(d, dir, path)))
		e = mkdir(d, dir, path);
	if (next)
		e = mkpath(d, e->head, next);
	return e;
}

File mkroot(Disk d)
{
	File dir = alloc(d);
	Entry up;

	up.head = dir;
	up.size[0] = 0;
	up.size[1] = 0;
	up.attr |= ATTR_FOLDER;
	strcpy(up.name, ".");

	memset(d[dir], 0, sizeof(up));
	memcpy(d[dir], &up, sizeof(up));

	return dir;
}

File format(Disk d)
{
	memset(d, 0, sizeof(Disk));
	d[0][0] = 255;
	return mkroot(d);
}

Entry *find(Disk d, File dir, char *name)
{
	int i;
	Entry *e = (Entry *)(&d[dir]);

	for (i = 0; i < SECTOR_SZ/sizeof(Entry); i++)
		if (strcmp(e[i].name, name) == 0)
			return &e[i];
	return 0;
}

int main(int argc, char *argv[])
{
	int i;
	FILE *f;
	File root, cwd;
	Entry *e;
	Disk d;

	cwd = root = format(d);

	for (i = 2; i < argc; i++) {
		if (strcmp(argv[i], "-d") == 0) {
			i++;
			if (strcmp(argv[i], "/") != 0)
				cwd = mkpath(d, root, argv[i])->head;
			else
				cwd = root;
			continue;
		}
		f = fopen(argv[i], "r");
		e = mkfile(d, cwd, argv[i]);
		store(d, e, f);
		fclose(f);
	}

	f = fopen(argv[1], "wb");
	fwrite(d, sizeof(Disk), 1, f);
	fclose(f);

	return 0;
}
