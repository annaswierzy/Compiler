def p(n,m,wynik):
    for i in range(0,n+1):
        for j in range(1,m+1):
            x=-m
            if(m>=0):
                for k in range(m,x-1,-1):
                    wynik=wynik+2
                    if(k!=0):
                        wynik=wynik//k
                    else:
                        wynik=0
                    wynik=wynik+n
                    if(x!=0):
                        wynik=wynik%x
                    else:
                        wynik=0
            else:
                wynik=wynik-3
                wynik=wynik*k
                wynik=wynik-n
                if(x!=0):
                    wynik=wynik//x
                else:
                    wynik=0
    
    return wynik


a = int(input("a = "))
b = int(input("b = "))
c=0
wynik=c
while(a>=0):
    for i in range(a,-6,-1):
        if(a<b):
            for j in range(a,b+1):
                wynik=a*b
                if(a!=0):
                    c=b%a
                else:
                    c=0
                wynik=wynik-c
        else:
            wynik=a*b
            if(b!=0):
                c=a//b
            else:
                c=0
            wynik=wynik+c

    wynik=p(a,b,wynik)
    print(wynik)
    a = int(input("a = "))
    b = int(input("b = "))