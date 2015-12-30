/* -*- C -*-
     SNMP.xs -- Perl 5 interface to the Net-SNMP toolkit

     written by G. S. Marzot (marz@users.sourceforge.net)

     Copyright (c) 1995-2006 G. S. Marzot. All rights reserved.
     This program is free software; you can redistribute it and/or
     modify it under the same terms as Perl itself.
*/
#define WIN32SCK_IS_STDSCK
#include "EXTERN.h"
#include "perl.h"
// #include "fake.h"
#include "XSUB.h"

#include <net-snmp/net-snmp-config.h>
#include <net-snmp/net-snmp-includes.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <errno.h>
#ifndef MSVC_PERL
	#include <signal.h>
#endif
#include <stdio.h>
#include <ctype.h>
#ifdef I_SYS_TIME
#include <sys/time.h>
#endif
#include <netdb.h>
#include <stdlib.h>
#ifndef MSVC_PERL
	#include <unistd.h>
#endif

#ifdef HAVE_REGEX_H
#include <regex.h>
#endif

#ifndef __P
#define __P(x) x
#endif

#ifndef na
#define na PL_na
#endif

#ifndef sv_undef
#define sv_undef PL_sv_undef
#endif

#ifndef stack_base
#define stack_base PL_stack_base
#endif

#ifndef G_VOID
#define G_VOID G_DISCARD
#endif

#define SUCCESS 1
#define FAILURE 0

#define ZERO_BUT_TRUE "0 but true"

#define TYPE_UNKNOWN 0
#define MAX_TYPE_NAME_LEN 32
#define STR_BUF_SIZE (MAX_TYPE_NAME_LEN * MAX_OID_LEN)
#define ENG_ID_BUF_SIZE 32

static int __is_numeric_oid _((char*));
static int __sprint_num_objid _((char *, oid *, int));
static int __scan_num_objid _((char *, oid *, size_t *));
static int __get_label_iid _((char *, char **, char **, int));
static struct tree * __tag2oid _((char *, char *, oid  *, size_t *, int *, int));
static int __concat_oid_str _((oid *, size_t *, char *));

#define USE_NUMERIC_OIDS 0x08
#define NON_LEAF_NAME 0x04
#define USE_LONG_NAMES 0x02
#define FAIL_ON_NULL_IID 0x01
#define NO_FLAGS 0x00

static int
__is_numeric_oid (oidstr)
char* oidstr;
{
  if (!oidstr) return 0;
  for (; *oidstr; oidstr++) {
     if (isalpha((int)*oidstr)) return 0;
  }
  return(1);
}

static int
__sprint_num_objid (buf, objid, len)
char *buf;
oid *objid;
int len;
{
   int i;
   buf[0] = '\0';
   for (i=0; i < len; i++) {
	sprintf(buf,".%lu",*objid++);
	buf += strlen(buf);
   }
   return SUCCESS;
}

static int
__scan_num_objid (buf, objid, len)
char *buf;
oid *objid;
size_t *len;
{
   char *cp;
   *len = 0;
   if (*buf == '.') buf++;
   cp = buf;
   while (*buf) {
      if (*buf++ == '.') {
         sscanf(cp, "%lu", objid++);
         /* *objid++ = atoi(cp); */
         (*len)++;
         cp = buf;
      } else {
         if (isalpha((int)*buf)) {
	    return FAILURE;
         }
      }
   }
   sscanf(cp, "%lu", objid++);
   /* *objid++ = atoi(cp); */
   (*len)++;
   return SUCCESS;
}

/* does a destructive disection of <label1>...<labeln>.<iid> returning
   <labeln> and <iid> in seperate strings (note: will destructively
   alter input string, 'name') */
static int
__get_label_iid (name, last_label, iid, flag)
char * name;
char ** last_label;
char ** iid;
int flag;
{
   char *lcp;
   char *icp;
   int len = strlen(name);
   int found_label = 0;

   *last_label = *iid = NULL;

   if (len == 0) return(FAILURE);

   /* Handle case where numeric oid's have been requested.  The input 'name'
   ** in this case should be a numeric OID -- return failure if not.
   */
   if ((flag & USE_NUMERIC_OIDS)) {
      if (!__is_numeric_oid(name))
       return(FAILURE);

      /* Walk backward through the string, looking for first two '.' chars */
      lcp = &(name[len]);
      icp = NULL;
      while (lcp > name) {
       if (*lcp == '.') {

          /* If this is the first occurence of '.', note it in icp.
          ** Otherwise, this must be the second occurrence, so break
          ** out of the loop.
          */
          if (icp == NULL)
             icp = lcp;
          else
             break;
       }
       lcp --;
      }

      /* Make sure we found at least a label and index. */
      if (!icp)
         return(FAILURE);

      /* Push forward past leading '.' chars and separate the strings. */
      lcp ++;
      *icp ++ = '\0';

      *last_label = (flag & USE_LONG_NAMES) ? name : lcp;
      *iid        = icp;

      return(SUCCESS);
   }

   lcp = icp = &(name[len]);

   while (lcp > name) {
      if (*lcp == '.') {
	if (found_label) {
	   lcp++;
           break;
        } else {
           icp = lcp;
        }
      }
      if (!found_label && isalpha((int)*lcp)) found_label = 1;
      lcp--;
   }

   if (!found_label || (!isdigit((int)*(icp+1)) && (flag & FAIL_ON_NULL_IID)))
      return(FAILURE);

   if (flag & NON_LEAF_NAME) { /* dont know where to start instance id */
     /* put the whole thing in label */
     icp = &(name[len]);
     flag |= USE_LONG_NAMES;
     /* special hack in case no mib loaded - object identifiers will
      * start with .iso.<num>.<num>...., in which case it is preferable
      * to make the label entirely numeric (i.e., convert "iso" => "1")
      */
      if (*lcp == '.' && lcp == name) {
         if (!strncmp(".ccitt.",lcp,7)) {
            name += 2;
            *name = '.';
            *(name+1) = '0';
         } else if (!strncmp(".iso.",lcp,5)) {
            name += 2;
            *name = '.';
            *(name+1) = '1';
         } else if (!strncmp(".joint-iso-ccitt.",lcp,17)) {
            name += 2;
            *name = '.';
            *(name+1) = '2';
         }
      }
   } else if (*icp) {
      *(icp++) = '\0';
   }
   *last_label = (flag & USE_LONG_NAMES ? name : lcp);

   *iid = icp;

   return(SUCCESS);
}


/* Convert a tag (string) to an OID array              */
/* Tag can be either a symbolic name, or an OID string */
static struct tree *
__tag2oid(tag, iid, oid_arr, oid_arr_len, type, best_guess)
char * tag;
char * iid;
oid  * oid_arr;
size_t * oid_arr_len;
int  * type;
int    best_guess;
{
   struct tree *tp = NULL;
   struct tree *rtp = NULL;
   oid newname[MAX_OID_LEN], *op;
   size_t newname_len = 0;

   char str_buf[STR_BUF_SIZE];
   str_buf[0] = '\0';

   if (type) *type = TYPE_UNKNOWN;
   if (oid_arr_len) *oid_arr_len = 0;
   if (!tag) goto done;

   /*********************************************************/
   /* best_guess = 0 - same as no switches (read_objid)     */
   /*                  if multiple parts, or uses find_node */
   /*                  if a single leaf                     */
   /* best_guess = 1 - same as -Ib (get_wild_node)          */
   /* best_guess = 2 - same as -IR (get_node)               */
   /*********************************************************/

   /* numeric scalar                (1,2) */
   /* single symbolic               (1,2) */
   /* single regex                  (1)   */
   /* partial full symbolic         (2)   */
   /* full symbolic                 (2)   */
   /* module::single symbolic       (2)   */
   /* module::partial full symbolic (2)   */
   if (best_guess == 1 || best_guess == 2) {
     if (!__scan_num_objid(tag, newname, &newname_len)) { /* make sure it's not a numeric tag */
       newname_len = MAX_OID_LEN;
       if (best_guess == 2) {		/* Random search -IR */
         if (get_node(tag, newname, &newname_len)) {
	   rtp = tp = get_tree(newname, newname_len, get_tree_head());
         }
       }
       else if (best_guess == 1) {	/* Regex search -Ib */
	 clear_tree_flags(get_tree_head());
         if (get_wild_node(tag, newname, &newname_len)) {
	   rtp = tp = get_tree(newname, newname_len, get_tree_head());
         }
       }
     }
     else {
       rtp = tp = get_tree(newname, newname_len, get_tree_head());
     }
     if (type) *type = (tp ? tp->type : TYPE_UNKNOWN);
     if ((oid_arr == NULL) || (oid_arr_len == NULL)) return rtp;
     memcpy(oid_arr,(char*)newname,newname_len*sizeof(oid));
     *oid_arr_len = newname_len;
   }

   /* if best_guess is off and multi part tag or module::tag */
   /* numeric scalar                                         */
   /* module::single symbolic                                */
   /* module::partial full symbolic                          */
   /* FULL symbolic OID                                      */
   else if (strchr(tag,'.') || strchr(tag,':')) {
     if (!__scan_num_objid(tag, newname, &newname_len)) { /* make sure it's not a numeric tag */
	newname_len = MAX_OID_LEN;
	if (read_objid(tag, newname, &newname_len)) {	/* long name */
	  rtp = tp = get_tree(newname, newname_len, get_tree_head());
	}
      }
      else {
	rtp = tp = get_tree(newname, newname_len, get_tree_head());
      }
      if (type) *type = (tp ? tp->type : TYPE_UNKNOWN);
      if ((oid_arr == NULL) || (oid_arr_len == NULL)) return rtp;
      memcpy(oid_arr,(char*)newname,newname_len*sizeof(oid));
      *oid_arr_len = newname_len;
   }

   /* else best_guess is off and it is a single leaf */
   /* single symbolic                                */
   else {
      rtp = tp = find_node(tag, get_tree_head());
      if (tp) {
         if (type) *type = tp->type;
         if ((oid_arr == NULL) || (oid_arr_len == NULL)) return rtp;
         /* code taken from get_node in snmp_client.c */
         for(op = newname + MAX_OID_LEN - 1; op >= newname; op--){
           *op = tp->subid;
	   tp = tp->parent;
	   if (tp == NULL)
	      break;
         }
         *oid_arr_len = newname + MAX_OID_LEN - op;
         memcpy(oid_arr, op, *oid_arr_len * sizeof(oid));
      } else {
         return(rtp);   /* HACK: otherwise, concat_oid_str confuses things */
      }
   }
 done:
   if (iid && *iid && oid_arr_len) __concat_oid_str(oid_arr, oid_arr_len, iid);
   return(rtp);
}

/* function: __concat_oid_str
 *
 * This function converts a dotted-decimal string, soid_str, to an array
 * of oid types and concatenates them on doid_arr begining at the index
 * specified by doid_arr_len.
 *
 * returns : SUCCESS, FAILURE
 */
static int
__concat_oid_str(doid_arr, doid_arr_len, soid_str)
oid *doid_arr;
size_t *doid_arr_len;
char * soid_str;
{
   char soid_buf[STR_BUF_SIZE];
   char *cp;
   char *st;

   if (!soid_str || !*soid_str) return SUCCESS;/* successfully added nothing */
   if (*soid_str == '.') soid_str++;
   strcpy(soid_buf, soid_str);
   cp = strtok_r(soid_buf,".",&st);
   while (cp) {
     sscanf(cp, "%lu", &(doid_arr[(*doid_arr_len)++]));
     /* doid_arr[(*doid_arr_len)++] =  atoi(cp); */
     cp = strtok_r(NULL,".",&st);
   }
   return(SUCCESS);
}

void
__libraries_init(char *appname)
    {
        static int have_inited = 0;

        if (have_inited)
            return;
        have_inited = 1;

        snmp_set_quick_print(1);
        init_snmp(appname);

        netsnmp_ds_set_boolean(NETSNMP_DS_LIBRARY_ID, NETSNMP_DS_LIB_DONT_BREAKDOWN_OIDS, 1);
        netsnmp_ds_set_int(NETSNMP_DS_LIBRARY_ID, NETSNMP_DS_LIB_PRINT_SUFFIX_ONLY, 1);
    netsnmp_ds_set_int(NETSNMP_DS_LIBRARY_ID, NETSNMP_DS_LIB_OID_OUTPUT_FORMAT,
                                              NETSNMP_OID_OUTPUT_SUFFIX);
        SOCK_STARTUP;

    }


MODULE = SNMP::Translate		PACKAGE = SNMP::Translate		PREFIX = snmp

void
init_snmp(appname)
        char *appname
    CODE:
        __libraries_init(appname);

int
snmp_add_mib_dir(mib_dir,force=0)
	char *		mib_dir
	int		force
	CODE:
        {
	int result = 0;      /* Avoid use of uninitialized variable below. */
        int verbose = SvIV(perl_get_sv("SNMP::Translate::verbose", 0x01 | 0x04));

        if (mib_dir && *mib_dir) {
	   result = add_mibdir(mib_dir);
        }
        if (result) {
           if (verbose) warn("snmp_add_mib_dir: Added mib dir %s\n", mib_dir);
        } else {
           if (verbose) warn("snmp_add_mib_dir: Failed to add %s\n", mib_dir);
        }
        RETVAL = (I32)result;
        }
        OUTPUT:
        RETVAL

int
snmp_read_mib(mib_file, force=0)
	char *		mib_file
	int		force
	CODE:
        {
        int verbose = SvIV(perl_get_sv("SNMP::Translate::verbose", 0x01 | 0x04));

        if ((mib_file == NULL) || (*mib_file == '\0')) {
           if (get_tree_head() == NULL) {
              if (verbose) warn("snmp_read_mib: initializing MIB\n");
              netsnmp_init_mib();
              if (get_tree_head()) {
                 if (verbose) warn("done\n");
              } else {
                 if (verbose) warn("failed\n");
              }
	   }
        } else {
           if (verbose) warn("snmp_read_mib: reading MIB: %s\n", mib_file);
           if (strcmp("ALL",mib_file))
              read_mib(mib_file);
           else
             read_all_mibs();
           if (get_tree_head()) {
              if (verbose) warn("done\n");
           } else {
              if (verbose) warn("failed\n");
           }
        }
        RETVAL = (IV)get_tree_head();
        }
        OUTPUT:
        RETVAL


int
snmp_read_module(module)
	char *		module
	CODE:
        {
        int verbose = SvIV(perl_get_sv("SNMP::Translate::verbose", 0x01 | 0x04));

        if (!strcmp(module,"ALL")) {
           read_all_mibs();
        } else {
           netsnmp_read_module(module);
        }
        if (get_tree_head()) {
           if (verbose) warn("Read %s\n", module);
        } else {
           if (verbose) warn("Failed reading %s\n", module);
        }
        RETVAL = (IV)get_tree_head();
        }
        OUTPUT:
        RETVAL

#define SNMP_XLATE_MODE_OID2TAG 1
#define SNMP_XLATE_MODE_TAG2OID 0

char *
snmp_translate_obj(var,mode,use_long,auto_init,best_guess,include_module_name)
	char *		var
	int		mode
	int		use_long
	int		auto_init
	int             best_guess
	int		include_module_name
	CODE:
	{
           char str_buf[STR_BUF_SIZE];
           char str_buf_temp[STR_BUF_SIZE];
           oid oid_arr[MAX_OID_LEN];
           size_t oid_arr_len = MAX_OID_LEN;
           char * label;
           char * iid;
           int status = FAILURE;
           int verbose = SvIV(perl_get_sv("SNMP::Translate::verbose", 0x01 | 0x04));
           struct tree *module_tree = NULL;
           char modbuf[256];
           int  old_format;   /* Current NETSNMP_DS_LIB_OID_OUTPUT_FORMAT */

           str_buf[0] = '\0';
           str_buf_temp[0] = '\0';

	   if (auto_init)
	     netsnmp_init_mib(); /* vestigial */

           /* Save old output format and set to FULL so long_names works */
           old_format = netsnmp_ds_get_int(NETSNMP_DS_LIBRARY_ID, NETSNMP_DS_LIB_OID_OUTPUT_FORMAT);
           netsnmp_ds_set_int(NETSNMP_DS_LIBRARY_ID, NETSNMP_DS_LIB_OID_OUTPUT_FORMAT, NETSNMP_OID_OUTPUT_FULL);

  	   switch (mode) {
              case SNMP_XLATE_MODE_TAG2OID:
		if (!__tag2oid(var, NULL, oid_arr, &oid_arr_len, NULL, best_guess)) {
		   if (verbose) warn("error:snmp_translate_obj:Unknown OID %s\n",var);
                } else {
                   status = __sprint_num_objid(str_buf, oid_arr, oid_arr_len);
                }
                break;
             case SNMP_XLATE_MODE_OID2TAG:
		oid_arr_len = 0;
		__concat_oid_str(oid_arr, &oid_arr_len, var);
		snprint_objid(str_buf_temp, sizeof(str_buf_temp), oid_arr, oid_arr_len);

		if (!use_long) {
                  label = NULL; iid = NULL;
		  if (((status=__get_label_iid(str_buf_temp,
		       &label, &iid, NO_FLAGS)) == SUCCESS)
		      && label) {
		     strcpy(str_buf_temp, label);
		     if (iid && *iid) {
		       strcat(str_buf_temp, ".");
		       strcat(str_buf_temp, iid);
		     }
 	          }
	        }

		/* Prepend modulename:: if enabled */
		if (include_module_name) {
		  module_tree = get_tree (oid_arr, oid_arr_len, get_tree_head());
		  if (module_tree) {
		    if (strcmp(module_name(module_tree->modid, modbuf), "#-1") ) {
		      strcat(str_buf, modbuf);
		      strcat(str_buf, "::");
		    }
		    else {
		      strcat(str_buf, "UNKNOWN::");
		    }
		  }
		}
		strcat(str_buf, str_buf_temp);

		break;
             default:
	       if (verbose) warn("snmp_translate_obj:unknown translation mode: %d\n", mode);
           }
           if (*str_buf) {
              RETVAL = (char*)str_buf;
           } else {
              RETVAL = (char*)NULL;
           }
           netsnmp_ds_set_int(NETSNMP_DS_LIBRARY_ID, NETSNMP_DS_LIB_OID_OUTPUT_FORMAT, old_format);
	}
        OUTPUT:
        RETVAL
