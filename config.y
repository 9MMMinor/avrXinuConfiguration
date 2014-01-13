/*
 *  config.y
 *  
 *
 *  Modified by Michael Minor on 6/1/10.
 *   cleaned up - removed all warnings. 10/05/11.
 *  Original from Xinu-TCPIP-Vol2_Distribution
 *	TCPIP-vol2.dist.tar.gz:
 *	ftp://ftp.cs.purdue.edu/pub/comer/TCPIP-vol2.dist.tar.gz
 *
 */
 
/*			Modification notes
 *
 *	Modifications are designed for the avr-gcc supported family of microprocessors.
 *	1) Change "conf.c" output for the file to be included inline in "initialize.c"
 *	2) Create include file "confisr.c" which adds code for interrupt service routines.
 *	3) Change some formats for compatibility with avr-gcc
 *	4) Change output to go to current directory. mmm 4/5/2013
 *
 */

%token DEFBRK COLON OCTAL INTEGER IDENT CSR IVEC OVEC IRQ IINT OINT
	INIT OPEN CLOSE	READ WRITE SEEK CNTL IS ON GETC PUTC
%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
	
extern char *yytext;
/*typedef size_t yy_size_t;*/
extern size_t yyleng;
	

#define	NIL	(dvptr)0

#define	CONFIGC		"conf.c"		/* name of .c output	*/
#define	CONFIGCISR	"confisr.c"	/* name of .c output	*/	
#define	CONFIGH		"conf.h"		/* name of .h output	*/
#define	CONFHREF	"<conf.h>"	/* how conf.h referenced*/
#define	CONFIGIN	"Configuration"		/* name of input file	*/
#define CONFavrioREF "<avr/io.h>"
#define CONFavrintREF "<avr/interrupt.h>"


#define	IRQBASE		32

FILE	*confc;
FILE	*confh;
FILE	*confisr;

char	*dbstr;
int	ndevs = 0;
int	currname = -1;
int	currtname = -1;
int	currdname = -1;
int	brkcount = 0;

struct	syment	{			/* symbol table			*/
	char	*symname;
	int	symoccurs;
	int	symtype;
	} symtab[250];

int	nsym = 0;
int	lookup();
int	linectr = 1;
char	*doing = "device type declaration";
char	*s;
struct	dvtype {
	char		*dvname;	/* device name (not used in types)*/
	char		*dvtname;	/* type name			*/
	int			dvtnum;		/* symbol table index of type	*/
	char		*dvdevice;	/* device name			*/
	int			dvcsr;		/* Control Status Register addr	*/
	char		dvivec[20];	/* input interrupt vector	*/
	char		dvovec[20];	/* Output interrupt vector	*/
	char		dviint[20];	/* input interrupt routine	*/
	char		dvoint[20];	/* output interrupt routine	*/
	char		dvinit[20];	/* init routine name		*/
	char		dvopen[20];	/* open routine name		*/
	char		dvclose[20];/* close routine name		*/
	char		dvread[20];	/* read routine name		*/
	char		dvwrite[20];/* write routine name		*/
	char		dvcntl[20];	/* control routine name		*/
	char		dvseek[20];	/* seek routine name		*/
	char		dvgetc[20];	/* getc routine name		*/
	char		dvputc[20];	/* putc routine name		*/
	int			dvminor;	/* device number 0,1,...	*/
	struct dvtype	*dvnext;/* next node on the list	*/
	};
typedef	struct	dvtype	*dvptr;
	dvptr	ftypes = NIL;		/* linked list of device types	*/
	dvptr	devs = NIL;		/* linked list of device decls.	*/
	dvptr	lastdv = NIL;
	dvptr	currtype = NIL;

char	*ftout[] = 
		{"struct\tdevsw\t{\t\t\t/* device table entry */\n",
		"\tint\tdvnum;\n",
		"\tchar\t*dvname;\n",
		"\tint\t(*dvinit)(struct devsw *);\n",
		"\tint\t(*dvopen)(struct devsw *, void *, void *);\n",
		"\tint\t(*dvclose)(struct devsw *);\n",
		"\tint\t(*dvread)(struct devsw *, unsigned char *, int);\n",
		"\tint\t(*dvwrite)(struct devsw *, unsigned char *, int);\n",
		"\tint\t(*dvseek)(struct devsw *, long);\n",
		"\tint\t(*dvgetc)(struct devsw *);\n",
		"\tint\t(*dvputc)(struct devsw *, unsigned char);\n",
		"\tint\t(*dvcntl)(struct devsw *, int, void *, void *);\n",
		"\tvoid\t*dvcsr;\n",
//		"\tint\tdvivec;\n",
//		"\tint\tdvovec;\n",
		"\tvoid\t(*dviint)(void *);\n",
		"\tvoid\t(*dvoint)(void *);\n",
		"\tvoid\t*dvioblk;\n",
		"\tint\tdvminor;\n",
		"\t};\n\n",
		"extern\tstruct\tdevsw devtab[];",
		"\t\t/* one entry per device */\n\n",
		NULL};

int l_atoi(char *, int);
void mktype(int);
int cktname(int);
void newattr(int, int);
void mkdev(int, int, int);
int ckdname(int);
void prdef(FILE *, char *, int);
int lookup(char *, int);
void initattr(dvptr, int, int);
int yylex(void);
int yyerror(char *);

%}
%%
config.input	:	devicetypes devicedescriptors
		;
devicetypes	:	ftypes DEFBRK
					{doing = "device definitions";}
		;
ftypes		:	/**/
		|	ftypes ftype
		;
ftype		:	tname device.list
		;
device.list	:	devheader attribute.list
		|	device.list devheader attribute.list
		;
devheader	:	ON id
					{mktype($2);}
		;
tname		:	id COLON
					{$$ = currtname = cktname($1);}
		;
id		:	IDENT
					{$$ = currname =
					 lookup(yytext,yyleng);
					}
		;
attribute.list	:	/**/
		|	attribute.list attribute
		;
attribute	:	CSR number
					{newattr(CSR,$2);}
//		|	IVEC number
//					{newattr(IVEC,$2);}
//		|	OVEC number
//					{newattr(OVEC,$2);}
		|	IVEC id
					{newattr(IVEC,$2);}
		|	OVEC id
					{newattr(OVEC,$2);}
//		|	IRQ number
		|	IRQ id
					{newattr(IRQ,$2 +IRQBASE);}
		|	IINT id
					{newattr(IINT,$2);}
		|	OINT id
					{newattr(OINT,$2);}
		|	OPEN id
					{newattr(OPEN,$2);}
		|	CLOSE id
					{newattr(CLOSE,$2);}
		|	INIT id
					{newattr(INIT,$2);}
		|	GETC id
					{newattr(GETC,$2);}
		|	PUTC id
					{newattr(PUTC,$2);}
		|	READ id
					{newattr(READ,$2);}
		|	WRITE id
					{newattr(WRITE,$2);}
		|	SEEK id
					{newattr(SEEK,$2);}
		|	CNTL id
					{newattr(CNTL,$2);}
		;
number		:	INTEGER
					{$$ = l_atoi(yytext,yyleng);}
		;
devicedescriptors	:	/**/
		|	devicedescriptors descriptor
		;
descriptor	:	fspec attribute.list
		;
fspec		:	dname IS id optional.on
					{mkdev($1,$3,$4);}
		;
dname		:	id
					{$$ = currdname = ckdname($1);}
		;
optional.on	:	/**/
					{$$ = 0;}
		|	ON id
					{$$ = $2;}
		;
%%
#include "lex.yy.c"

void Strdup(char *, char *, int);

int main(int argc, char	*argv[])
{
	int	n, i, fcount;
	dvptr	s;
	int	verbose = 0;
	char	*p;
	char	c;

	if (argc>1 && (strcmp("-v",argv[1])==0)) {
		argc--;
		argv++;
		verbose++;
	}
	if (argc>2) {
		fprintf(stderr,"use: config [-v] [file]\n");
		exit(1);
	}
	if (verbose)
		printf("Opening input file...\n");
	if (argc == 2) {
		if (freopen(argv[1], "r", stdin) == NULL) {
			fprintf(stderr,"Can't open %s\n",argv[1]);
			exit(1);
		}
	} else {	/* try to open Configuration file */
		if (freopen(CONFIGIN, "r", stdin) == NULL) {
			fprintf(stderr,"Can't open %s\n", CONFIGIN);
			exit(1);
		}
	}

	/* Parse the Configuration file */

	if (verbose)
		printf("Parsing configuration specs...\n");
	if ((n=yyparse()) != 0)
		exit(n);

	/* write config.h and config.c */

	if (verbose)
		printf("Opening output files...\n");
	if ( (confc=fopen(CONFIGC,"w") ) == NULL) {
		fprintf(stderr, "Can't write on %s\n", CONFIGC);
		exit(1);
	}
	if ( (confisr=fopen(CONFIGCISR,"w") ) == NULL) {
		fprintf(stderr, "Can't write on %s\n", CONFIGC);
		exit(1);
	}
	if ( (confh=fopen(CONFIGH,"w") ) == NULL) {
		fprintf(stderr, "Can't write on %s\n", CONFIGH);
		exit(1);
	}
	fprintf(confh,
		"/* conf.h (GENERATED FILE; DO NOT EDIT) */\n");
	fprintf(confc,
		"/* conf.c (GENERATED FILE; DO NOT EDIT) */\n");
	fprintf(confisr,
		"/* confisr.c (GENERATED FILE; Edits are overwritten by config) */\n");
//	fprintf(confc, "\n#include %s\n", CONFHREF);
//	fprintf(confh, "\n#define\tNULLPTR\t(void *)0\n");


	if (verbose)
		printf("Writing output...\n");
	fprintf(confh,"\n/* Device table declarations */\n");
	for (i=0 ; (p=ftout[i])!=NULL ; i++)
		fprintf(confh, "%s", p);

	/* write device declarations and definitions; count type refs. */

	fprintf(confh, "\n/* Device name definitions */\n\n");
	for (i=0,s=devs; s!=NIL ; s=s->dvnext,i++) {
		fprintf(confh, "#define\t%-12s%d\t\t\t/* type %-8s */\n",
			s->dvname, i, s->dvtname);
		s->dvminor = symtab[s->dvtnum].symoccurs++;
	}

	/* write count of device types */

	fprintf(confh,"\n/* Control block sizes */\n\n");
	for (i=0 ; i<nsym ; i++)
		if (symtab[i].symoccurs > 0) {
			fprintf(confh, "#define\tN%s\t%d\n",
				symtab[i].symname, symtab[i].symoccurs);
		}
	if (ndevs > 0)
		fprintf(confh, "\n#define\tNDEVS\t%d\n\n", ndevs);

	/* empty symbol table, collect, and write names of all I/O routines */

	nsym = 0;
	for (s=devs; s!=NIL ; s=s->dvnext) {
		i=lookup(s->dvinit,strlen(s->dvinit));
		symtab[i].symtype = INIT;
		i=lookup(s->dvopen,strlen(s->dvopen));
		symtab[i].symtype = OPEN;
		i=lookup(s->dvclose,strlen(s->dvclose));
		symtab[i].symtype = CLOSE;
		i=lookup(s->dvread,strlen(s->dvread));
		symtab[i].symtype = READ;
		i=lookup(s->dvwrite,strlen(s->dvwrite));
		symtab[i].symtype = WRITE;
		i=lookup(s->dvseek,strlen(s->dvseek));
		symtab[i].symtype = SEEK;
		i=lookup(s->dvcntl,strlen(s->dvcntl));
		symtab[i].symtype = CNTL;
		i=lookup(s->dvgetc,strlen(s->dvgetc));
		symtab[i].symtype = GETC;
		i=lookup(s->dvputc,strlen(s->dvputc));
		symtab[i].symtype = PUTC;
		i=lookup(s->dviint,strlen(s->dviint));
		symtab[i].symtype = IINT;
		i=lookup(s->dvoint,strlen(s->dvoint));
		symtab[i].symtype = OINT;
		
	}
	fprintf(confh,
		"/* Declarations of I/O routines referenced */\n\n");
	for (i=0 ; i<nsym ; i++) 
		prdef(confh, symtab[i].symname, symtab[i].symtype);

	/* produce devtab (giant I/O switch table) */

	fprintf(confc, "\n/* device independent I/O switch */\n\n");
	if (ndevs > 0) {
		fprintf(confc, "struct\tdevsw\tdevtab[NDEVS] = {\n");		/**** OPEN ****/
		fprintf(confc, "\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n",
			"/*  Format of entries is:",
			"device-number, device-name,",
			"init, open, close,",
			"read, write, seek,",
			"getc, putc, cntl,",
			"device-csr-address, iint-handler, oint-handler,",
			"control-block, minor-device,",
			"*/");
	}
	for (fcount=0,s=devs ; s!=NIL ; s=s->dvnext,fcount++) {
		fprintf(confc, "\n/*  %s  is %s  */\n\n",s->dvname,s->dvtname);
		fprintf(confc, "{%d, \"%s\",\n", fcount, s->dvname);		/***** OPEN BRACE ****/
		fprintf(confc, "(void *)%s, (void *)%s, (void *)%s,\n",
			s->dvinit, s->dvopen, s->dvclose);
		fprintf(confc, "(void *)%s, (void *)%s, (void *)%s,\n",
			s->dvread, s->dvwrite, s->dvseek);
		fprintf(confc, "(void *)%s, (void *)%s, (void *)%s,\n",
			s->dvgetc, s->dvputc, s->dvcntl);
		fprintf(confc, "(void *)0x%02X, ",
			s->dvcsr);
		fprintf(confc, "(void *)%s, (void *)%s,\nNULLPTR, %d",
			s->dviint, s->dvoint, s->dvminor);
		if ( s->dvnext != NIL )
			fprintf(confc, "},\n");									/**** CLOSE BRACE ****/
		else
			fprintf(confc, "}\n\t};");								/**** CLOSE ****/
	}
/********** avr-Xinu *****************/
	fprintf(confisr,
			"\n\n/* Interrupt Service routines referenced */\n\n");
	for (fcount =0,s=devs; s!=NIL ; s=s->dvnext,fcount++) {
		if (strlen(s->dvivec) > 0) {
			//			fprintf(confisr, "ISR(_VECTOR(%d))\n{\n", s->dvivec);
			fprintf(confisr, "ISR(%s)\n{\n", s->dvivec);
			fprintf(confisr, "\t%s(&%s[%d]);\n}\n", s->dviint, s->dvtname, s->dvminor);
		}
		if (strlen(s->dvovec) > 0 && strcmp(s->dvivec,s->dvovec) != 0) {
			//			fprintf(confisr, "ISR(_VECTOR(%d))\n{\n", s->dvovec);
			fprintf(confisr, "ISR(%s)\n{\n", s->dvovec);
			fprintf(confisr, "\t%s(&%s[%d]);\n}\n", s->dvoint, s->dvtname, s->dvminor);
		}
	}		
/********** avr-Xinu *****************/
	

	/* Copy definitions to output */

	if (brkcount == 2 && verbose)
		printf("Copying definitions to %s...\n", CONFIGH);
	if (brkcount == 2 )
		while ( (c=input()) > 0)	/* lex input routine */
			putc(c, confh);

	/* guarantee conf.c written later than conf.h for make */

	fclose(confh);
	fprintf(confc, "\n");
	fclose(confc);
	fprintf(confisr, "\n");
	fclose(confisr);

	/* finish up and write report for user if requested */

	if (verbose) {
	    printf("\nConfiguration complete. Number of devs=%d:\n\n",ndevs);
	    for (s=devs; s!=NIL ; s=s->dvnext)
	      printf(
	        "Device %s (on %s) csr=0x%0X, ivec=%s, ovec=%s, minor=%d\n",
		s->dvname, s->dvdevice, s->dvcsr, s->dvivec, s->dvovec,
		s->dvminor);
	}
	

}


int yyerror(char *s)
{
	return (fprintf(stderr,"Syntax error in %s on line %d\n",
		doing,linectr) );
}


/*  lookup  --  lookup a name in the symbol table; return position */

int lookup(char *str, int len)
{
	int	i;
	char	*s;

	if (len >= 20) {
		len = 19;
		fprintf(stderr,"warning: name %s truncated\n",str);
		}
	s = (char *)malloc(len+1);
	strncpy(s,str,len);
	s[len] = '\000';
	for (i=0 ; i<nsym ; i++)
		if (strcmp(s,symtab[i].symname) == 0){
			return(i);
		}
	symtab[nsym].symname = s;
	symtab[nsym].symoccurs = 0;
	return(nsym++);
}

int
l_atoi(p, len)
char	*p;
int	len;
{
	int	base, rv;

	if (*p == '0') {
		++p; --len;
		if (*p == 'x' || *p == 'X') {
			++p; --len;		/* skip 'x' */
			base = 16;
		} else
			base = 8;
	} else
		base = 10;
	rv = 0;
	for (; len > 0; ++p, --len) {
		rv *= base;
		if (isdigit(*p))
			rv += *p - '0';
		else if (isupper(*p))
			rv += *p - 'A' + 10;
		else
			rv += *p - 'a' + 10;
	}
	return rv;
}

/* newattr(tok, val) -- add a new attribute spec to current type/device description	*/
/* tok -> token type (attribute type)	*/
/* val -> symbol number of value	*/

void newattr(int tok, int val)			
{
	char	*c;
	dvptr	s;

	if (devs == NIL)		/* doing types			*/
		s = currtype;
	else
		s = lastdv;
	if (val>=0 && val<nsym) {
		c = symtab[val].symname;
		if (strlen(c) > 20 ) {
			fprintf(stderr,"Internal overflow\n");
			exit(1);
		}
	} else
		c = NULL;

	switch (tok) {

	case CSR:	s->dvcsr = val;
			break;
//	case IVEC:	s->dvivec = val;
	case IVEC:	strcpy(s->dvivec,c);
			break;
//	case OVEC:	s->dvovec = val;
	case OVEC:	strcpy(s->dvovec,c);
			break;
	case IRQ:	strcpy(s->dvivec,c);
			strcpy(s->dvovec,c);
			break;
	case IINT:	strcpy(s->dviint,c);
			break;
	case OINT:	strcpy(s->dvoint,c);
			break;
	case READ:	strcpy(s->dvread,c);
			break;
	case WRITE:	strcpy(s->dvwrite,c);
			break;
	case GETC:	strcpy(s->dvgetc,c);
			break;
	case PUTC:	strcpy(s->dvputc,c);
			break;
	case OPEN:	strcpy(s->dvopen,c);
			break;
	case CLOSE:	strcpy(s->dvclose,c);
			break;
	case INIT:	strcpy(s->dvinit,c);
			break;
	case SEEK:	strcpy(s->dvseek,c);
			break;
	case CNTL:	strcpy(s->dvcntl,c);
			break;
	default:	fprintf(stderr, "Internal error 1\n");
	}
}

/* cktname  --  check type name for duplicates */

int cktname(int symid)
{
	dvptr	s;
extern	dvptr	ftypes;
	char	*name;

	name = symtab[symid].symname;
	for (s=ftypes; s!=NIL ; s=s->dvnext) {
		if (s->dvtname == name) {
			fprintf(stderr,"Duplicate type name %s on line %d\n",
				name,linectr);
			exit(1);
			}
		}
	return(symid);
}

/* mktype  --  make a node in the type list and initialize to defaults	*/

void mktype(int deviceid)
{
	dvptr	s,p;
	char	*tn,*dn;

	p = NIL;
	tn = symtab[currtname].symname;
	dn = symtab[deviceid].symname;
	for (s = ftypes; s!=NIL ; s=s->dvnext) {
		if (s->dvtname == tn && s->dvdevice==dn) {
		   fprintf(stderr,
		     "Duplicate device %s for type %s on line %d\n",
		     dn, tn, linectr);
		   exit(1);
		}
		p = s;
	}
	currtype = s = (dvptr) malloc( sizeof(struct dvtype));
	if (ftypes != NIL) {
		p->dvnext = s;
	}
	else {
		ftypes = s;
	}
	initattr(s, currtname, deviceid);
}

/* initialize attributes in a type declaration node to typename...	*/

void initattr(fstr, tnum, deviceid)
	dvptr	fstr;
	int	tnum;
	int	deviceid;
{
	char	*typnam;

	typnam = symtab[tnum].symname;
	fstr->dvname = NULL;
	fstr->dvtname = typnam;
	fstr->dvtnum = tnum;
	fstr->dvdevice = symtab[deviceid].symname;
	fstr->dvcsr = 0;
//	fstr->dvivec = 0;
	strcpy(fstr->dvivec,"");
//	fstr->dvovec = 0;
	strcpy(fstr->dvovec,"");
	strcpy(fstr->dviint,typnam);
	strcat(fstr->dviint,"iin");
	strcpy(fstr->dvoint,typnam);
	strcat(fstr->dvoint,"oin");
	strcpy(fstr->dvinit,typnam);
	strcat(fstr->dvinit,"init");
	strcpy(fstr->dvopen,typnam);
	strcat(fstr->dvopen,"open");
	strcpy(fstr->dvclose,typnam);
	strcat(fstr->dvclose,"close");
	strcpy(fstr->dvread,typnam);
	strcat(fstr->dvread,"read");
	strcpy(fstr->dvwrite,typnam);
	strcat(fstr->dvwrite,"write");
	strcpy(fstr->dvcntl,typnam);
	strcat(fstr->dvcntl,"control");
	strcpy(fstr->dvseek,typnam);
	strcat(fstr->dvseek,"seek");
	strcpy(fstr->dvgetc,typnam);
	strcat(fstr->dvgetc,"getc");
	strcpy(fstr->dvputc,typnam);
	strcat(fstr->dvputc,"putc");
	fstr->dvminor = 0;
}

/* mkdev  --  make a node on the device list */

void mkdev(int nameid, int typid, int deviceid)
{
	dvptr	s;
	char	*devn,*tn,*dn;
	int	found;

	s = (dvptr) malloc(sizeof(struct dvtype));
	s->dvnext = NIL;
	if (devs == NIL) {
		devs = s;
		lastdv = s;
	} else {
		lastdv->dvnext = s;
		lastdv = s;
	}
	ndevs++;
	tn = symtab[typid].symname;
	devn = symtab[nameid].symname;
	if (deviceid >= 0)
		dn = symtab[deviceid].symname;
	else
		dn = NULL;
	found = 0;
	for (s=ftypes ; s != NULL ; s=s->dvnext)
		if (s->dvtname == tn && (dn==NULL || s->dvdevice==dn)) {
			Strdup((char *)lastdv,(char *)s,sizeof(struct dvtype));
			found=1;
			break;
		}
	if (found==0) {
		fprintf(stderr,
		  "Bad type or device name in declaration of %s on line %d\n",
		  devn, linectr);
		exit(1);
	}
	lastdv->dvnext = NIL;
	lastdv->dvname = devn;
}


/* chdname  -- check for duplicate device name */

int ckdname(int devid)
{
	dvptr	s;
extern	dvptr	devs;
	char	*name;

	name = symtab[devid].symname;
	for (s=devs; s!=NIL ; s=s->dvnext) {
		if (s->dvname == name) {
			fprintf(stderr,"Duplicate device name %s on line %d\n",
				name,linectr);
			exit(1);
			}
		}
	return(devid);
}

void Strdup(char *tostr, char *fromstr, int len)
{
	for( ; len > 0 ; len--)
		*tostr++ = *fromstr++;
}

void prdef(FILE *fp, char *name, int typ)
{
	/* special case for the everything function */
/*	if (strcmp(name, "ioerr") == 0) {
		fprintf(fp, "extern\tvoid\tioerr(void);\n");
		return;
	}
	switch (typ) {
	case IINT:
		fprintf(fp, "extern\tvoid\t%s(void *);\n", name);
		break;
	case OINT:
		fprintf(fp, "extern\tvoid\t%s(void *);\n", name);
		break;
	case READ:
		fprintf(fp, "extern\tint\t%s(struct devsw *, unsigned char *, int);\n", name);
		break;
	case WRITE:
		fprintf(fp, "extern\tint\t%s(struct devsw *, unsigned char *, int);\n", name);
		break;
	case GETC:
		fprintf(fp, "extern\tint\t%s(struct devsw *);\n", name);
		break;
	case PUTC:
		fprintf(fp, "extern\tint\t%s(struct devsw *, unsigned char);\n",
			name);
		break;
	case OPEN:
		fprintf(fp, "extern\tvoid *\t%s(struct devsw *, void *, void *);\n", name);
		break;
	case CLOSE:
		fprintf(fp, "extern\tint\t%s(struct devsw *);\n", name);
		break;
	case INIT:
		fprintf(fp, "extern\tint\t%s(struct devsw *);\n", name);
		break;
	case SEEK:
		fprintf(fp, "extern\tint\t%s(struct devsw *, long);\n", name);
		break;
	case CNTL:
		fprintf(fp, "extern\tint\t%s(struct devsw *, int, void *, void *);\n",
			name);
		break;
	default:	fprintf(stderr, "Internal error 1\n");
	}
 */
}

