def p(n,m,wynik):
    x=-m
    for i in range(0,n+1):
        if(m>=0):
            for j in range(1,m+1):
                for k in range(m,x-1,-1):
                    wynik=wynik+2
                    if(k!=0):
                        wynik=wynik//k
                    else:
                        wynik=0
                    wynik=wynik*n
                    if(x!=0):
                        wynik=wynik%x
                    else:
                        wynik=0
        else:
            for j in range(-1,m-1,-1):
                for k in range (x,m-1,-1):
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
                c=i*j
                wynik=wynik+c
                if(a!=0):
                    c=j%a
                else:
                    c=0
                wynik=wynik-c
        else:
            for j in range(b,a+1):
                c=i*j
                wynik=wynik+c
                if(i!=0):
                    c=a//i
                else:
                    c=0
                wynik=wynik+c

    print(wynik)
    wynik=p(a,b,wynik)
    print(wynik)
    a = int(input("a = "))
    b = int(input("b = "))
    c=0
    wynik=c
