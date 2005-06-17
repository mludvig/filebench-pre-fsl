#!/bin/sh

flag="SHORT"
if [ "$1" = "-v" ]; then
  flag="LONG";
fi

prtconf -v | cut -c1-80 | nawk -v flag=$flag '
BEGIN {
    overflow=10000;
    sys_type="SPARC"; # default
}
/^\#/ { next; }
/^[	]*$/ { next; }
/total/{
    exit;
}
{
    if ($5 ~ /i86pc/) {
#        printf("i86pc SYSTEM\n" );
        sys_type="i86pc";
    } else if ($5 ~ /sun4u/) {
#        printf("sun4u SYSTEM\n" ); # ZF
        sys_type="SPARC";
    }

    if (sys_type == "i86pc") {
        if ($0 ~ /cpu, instance/) {
            cpu[$3] = 1;
            last_cpu=$3;
#            printf("cpu instance %s\n", $3);
        } else if ($0 ~ /brand-string/) {
            getline;
            split($0, brand_name, "=");
#            brand[last_cpu] = brand_name[2];
            gsub("\047 *", "", brand_name[2]);
            brand[last_cpu] = brand_name[2];
        } else if ($0 ~ /cpu-model/) {
            getline;
            split($0, model_string, "=");
#            model[last_cpu] = model_string[2];
            gsub("^0*", "", model_string[2]);
            model[last_cpu] = model_string[2];
        }
    } else if (sys_type == "SPARC") {
        if ($0 ~ /SUNW,UltraSPARC/) {
            split($1, hw_names, ",");
            if ($0 ~ /instance/) {
                cpu[$3] = 1;
                last_cpu=$3;
                brand[last_cpu]=hw_names[2];
            }
            getline;
            if ($0 ~ /SUNW,/) {
                getline;
            }
            if ($0 ~ /instance/) {
                cpu[$3] = 1;
                last_cpu=$3;
#                printf("cpu instance %s\n", $3);
                brand[last_cpu]=hw_names[2];
            }
        }
    } else {
        printf("Unknown system type: %s\n", $0);
        exit;
    }
}
END  {
    if (flag == "SHORT") {
        type="SPARC";
        for(c in cpu) {
            if (brand[c] ~ /Opteron/) {
                type = "Opteron";
            } else if (brand[c] ~ /Xeon/) {
                type = "Xeon";
            } else if (brand[c] ~ /UltraSPARC/) {
#                type = brand[c];
                type = "SPARC";
            }
        }
        printf("%s\n", type);
        exit;
    }
    for(c in cpu) {
        printf("CPU %s: ", c);
        printf("brand=\047%s\047,", brand[c]);
        printf("model=\047%s\047\n", model[c]);
    }
}
'
