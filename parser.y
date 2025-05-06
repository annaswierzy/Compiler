%{
//Author Anna Świerzy

#include <iostream>
#include <string>
#include <vector>
#include <cstdlib>
#include <cstdio>
#include <cstring> 
#include <sstream>
#include <algorithm>

extern FILE* yyin;
extern FILE* yyout;
extern int yyparse();

extern int yylex();

extern int yylineno;

void yyerror(const char* msg);

long long memory = 0;
const long long MEMORY_LIMIT = 1LL << 62;

bool error = false;

struct variable {
    char* name;

    bool tab;
    long long start_index = 0;
    long long end_index = 0;

    bool is_arg = 0;
    bool is_itarator = 0;
    bool assign = 0;

    long long memory;
};

std::vector<variable> variables;
std::vector<std::vector<variable>> var_proc;

long long licznik_proc = 0;
long long licznik_teraz = 0;

struct proc {
    char* name = nullptr; 
    long long line = 0; 
    std::vector<variable> args;
    long long memory = -1;
    long long licznik = 0;
};

std::vector<proc> procedures;

std::vector<std::string> output_code;

long long lines = 0;

bool check_var(char* name){
    for(variable var : variables){
        if(strcmp(var.name, name) == 0){
            return false;   
        }
    }
    return true;
}

bool check_proc(char* name){
    for(proc p : procedures){
        if(strcmp(p.name, name) == 0){
            return false;   
        }
    }
    return true;
}

void check_memory(){
    if (memory > MEMORY_LIMIT) {
        std::cerr << "Przekroczono pamięć\n";
        exit(1);
    }
    return;
}

void add_arg(char* name, long long line){
    if(!check_var(name)){
        error = true;
        std::cerr<< "błąd: druga deklaracja argumentu : linia " << line <<"\n"; 
    }
    else{
        variable argument;
        argument.name = name;
        argument.tab = false;
        argument.is_arg = true;
        argument.memory = memory + 1;
        memory ++;
        check_memory();
        variables.push_back(argument);
    }
}

void add_tab_arg(char* name, long long line){
    if(!check_var(name)){
        error = true;
        std::cerr<< "błąd: druga deklaracja argumentu : linia "<<line<<"\n"; 
    }
    else{
        variable argument;
        argument.name = name;
        argument.tab = true;
        argument.is_arg = true;
        argument.memory = memory + 1;
        memory ++;
        check_memory();
        variables.push_back(argument);
    }
}

void create_proc(char* name, long long line){
    if(!check_proc(name)){
        error = true;
        std::cerr<< "błąd: druga deklaracja procedury : linia "<<line<<"\n"; 
    }
    else{
        proc procedure;
        procedure.name = name;
        procedure.args = variables;
        procedure.memory = memory + 1;
        memory ++;
        check_memory();
        procedure.licznik = licznik_proc;
        licznik_proc++;
        procedures.push_back(procedure);
    }
}

void add_var(char* name, long long line){
    if(!check_var(name)){
        error = true;
        std::cerr<< "błąd: druga deklaracja zmiennej : linia "<<line <<"\n";
    }
    else{
        variable var;
        var.name = name;
        var.tab = false;
        var.is_arg = false;
        var.memory = memory + 1;
        memory ++;
        check_memory();
        variables.push_back(var);
    }
}

void add_tab_var(char* name, long long start_index, long long end_index, long long line){
    if(!check_var(name)){
        error = true;
       std::cerr<< "błąd: druga deklaracja zmiennej : linia "<<line<<"\n"; 
    }
    else{
        variable var;
        var.name = name;
        var.tab = true;
        if(start_index > end_index){
            error = true;
            std::cerr << "błąd: ujemna wielość tablicy "<< name << " : linia "<<line<<"\n";
        }
        var.start_index = start_index;
        var.end_index = end_index;
        var.is_arg = false;
        long long l = end_index - start_index + 1;
        var.memory = memory + 1;
        memory = memory + l;
        check_memory();
        variables.push_back(var);
    }
}

proc find_proc(char* name, long long line){
    for(proc& p : procedures){
        if(strcmp(p.name, name) == 0){
            p.line =lines;
            if(p.licznik == 0){
                p.line++;
            }
            return p;   
        }
    }
    error = true;
    std::cerr << "błąd:  nie znaleziono procedury "<< name <<" : linia "<< line<<"\n";
    proc p;
    name = nullptr;
    return p;
} 

enum NodeType {
    NODE_END,
    NODE_PROC,
    NODE_MAIN,
    NODE_COMMANDS,
    NODE_IF,         
    NODE_FOR,         
    NODE_FORDWONTO,       
    NODE_WHILE,     
    NODE_REPEAT,     
    NODE_ASSIGN,     
    NODE_ARITHMETIC, 
    NODE_CONDITION,
    NODE_NUM,
    NODE_VAR,
    NODE_TAB,
    NODE_CALL,
    NODE_WRITE,
    NODE_READ,
    NODE_ARG  
};

struct ASTNode {
    NodeType type;      // Typ węzła
    char* value;  
    long long line;                
    std::vector<ASTNode*> children; 
};

ASTNode* create_node(NodeType type, const char* value, long long line) {
    ASTNode* node = new ASTNode;
    node->type = type;
    node->value = value ? strdup(value) : nullptr;
    node->children = std::vector<ASTNode*>();
    node->line = line;
    return node;
}

void add_child(ASTNode* parent, ASTNode* child) {
    if(parent && child){
        parent->children.push_back(child);
    }
}

void print_ast(ASTNode* node, int depth = 0) {
    if(node == nullptr) return;
    for (int i = 0; i < depth; ++i) printf("  ");
    printf("%s\n", node->value ? node->value : "Unknown");

    for (ASTNode* child : node->children) {
        print_ast(child, depth + 1);
    }
}

variable find_var(char* name, bool change = 0){
    for(variable& var : variables){
        if(strcmp(var.name, name) == 0){
            if(change == 1){
                var.assign = 1;
            }
            return var;   
        }
    }
    variable var;
    var.name=nullptr;
    return var;
}

std::vector<std::string>  call(ASTNode* node){
    std::vector<std::string> code;

    for(proc p : procedures){

        if(strcmp(p.name, node->value) == 0){
            if(licznik_teraz <= p.licznik){
                error = true;
                std::cerr<<"błąd: niezdefiniowana procedura "<<  p.name << " : linia "<<node->line<<"\n";
                return code;
            }
            ASTNode* args = node->children[0];          

            if(p.args.size()==args->children.size()){

                for(size_t i = 0; i <args->children.size(); i++){

                    char* name = args->children[i]->value;

                    variable var = find_var(name, 1); 
                    if(var.name == nullptr){
                        error = true;
                       std:: cerr<<"błąd: nie ma takiej zmiennej "<< name <<" : linia "<< args->children[i]->line<<"\n";
                        return code;
                    }

                    if(var.tab != p.args[i].tab){
                        error = true;
                        std::cerr<< "błąd: zły rodzaj argumentu "<<name<<" : linia "<<args->children[i]->line<<"\n";
                        return code;
                    }
                    if(var.is_itarator == 1){
                        error = true;
                        std::cerr<< "błąd: nie można przekazywać iteratora do procedury : linia "<<args->children[i]->line<<"\n";
                        return code;
                    }

                    //wrzucenie gdzie liczba jest do argumentu
                    if(var.is_arg == 0){
                        long long place = var.memory;
                        if(var.tab == true){
                            place = place - var.start_index;
                        }
                        code.push_back("SET "+ std::to_string(place));
                        code.push_back("STORE "+ std::to_string(p.args[i].memory));
                    }
                    else{
                        code.push_back("LOAD "+ std::to_string(var.memory));
                        code.push_back("STORE "+ std::to_string(p.args[i].memory));
                    }
                }
                code.push_back("SET linika + 4");
                code.push_back("STORE "+ std::to_string(p.memory));
                code.push_back("JUMP - linijka + "+ std::to_string(p.line));
                return code;
            }
            else{
                error = true;
                std::cerr<< "błąd: nie znaleziono procedury - zła ilość argumentów : linia "<<node->line<<"\n"; 
            }
            return code;
        }
    }
    error = true;
    std::cerr << "błąd:  nie znaleziono procedury "<< node->value <<" : linia "<<node->line<<"\n";
    return code;
}

//funkcja znajduje gdzie w pamięci jest dany element tablicy
long long find_memory_tab(variable& tab, long long num, long long line){
    if(num<tab.start_index or num > tab.end_index){
        error = true;
        std:: cerr<<"błąd: wychodzimy poza tablice "<< tab.name << " : linia "<<line<<"\n";
        return -1;
    }
    return tab.memory + num - tab.start_index;
}

std::vector<std::string> write(ASTNode* node){
    std::vector<std::string> code;
    ASTNode* child = node->children[0];
    if(child->type == NODE_NUM){
        //numer
        code.push_back(std::string("SET ") + child->value);
        code.push_back("PUT "+ std::to_string(0));
    }
    else{
        for(variable var : variables){
            if(strcmp(var.name, child->value) == 0 ){
                //zmienna
                if(var.tab == 0){
                    if(child->type == NODE_TAB){
                        error = true;
                        std:: cerr<<"błąd: złe użycie zmiennej "<< var.name << " : linia "<<child->line<<"\n";
                        return code;
                    }
                    //zwykła zmienna
                    if(var.is_arg == 0){
                        if(var.assign == 1){
                            code.push_back("PUT "+ std::to_string(var.memory));
                        }
                        else{
                            error = true;
                            std:: cerr<<"błąd: nie przypisaliśmy wartości do zmiennej "<< var.name << " : linia "<<child->line<<"\n";
                            return code;
                        }
                    }
                    //zmienna-argument
                    else{
                        code.push_back("LOADI "+ std::to_string(var.memory));
                        code.push_back("PUT "+ std::to_string(0));
                    }
                }
                //tablica
                else{
                    if(child->children.size() == 0){
                        error = true;
                        std::cerr<<"błąd: nie podano miejsca w tablicy "<< var.name << " : linia "<<child->line<<"\n";
                        return code;
                    }
                    ASTNode* index = child->children[0];
                    //zwykła tablica
                    if(var.is_arg == 0){
                        //tablica numer
                        if(index->type == NODE_NUM){
                            long long mem = find_memory_tab(var, std::stoll(std::string(index->value)), index->line);
                            if(mem != -1){
                                code.push_back("PUT "+ std::to_string(mem));
                            }
                        }
                        //tablice zmienna
                        else{
                            for(variable in : variables){
                                if(strcmp(in.name, index->value) == 0 ){
                                    //tablica zmienna
                                   if(in.is_arg == 0){
                                        if(in.assign == 1){
                                            //miejsce o indeksie 0 w tablicy
                                            long long mem0 = var.memory - var.start_index;
                                            code.push_back("SET "+ std::to_string(mem0));
                                            code.push_back("ADD "+ std::to_string(in.memory));
                                            code.push_back("LOADI "+ std::to_string(0));
                                            code.push_back("PUT "+ std::to_string(0));
                                            return code;
                                        }
                                        else{
                                            error = true;
                                            std:: cerr<<"błąd: nie przypisaliśmy wartości do zmiennej "<< var.name << " : linia "<<index->line<<"\n";
                                            return code;
                                        }
                                   } 
                                   //tablica zmienna-argument
                                   else{
                                         //miejsce o indeksie 0 w tablicy
                                        long long mem0 = var.memory - var.start_index;
                                        code.push_back("SET "+ std::to_string(mem0));
                                        code.push_back("ADDI "+ std::to_string(in.memory));
                                        code.push_back("LOADI "+ std::to_string(0));
                                        code.push_back("PUT "+ std::to_string(0));
                                        return code;
                                   }
                                }
                            }
                            std:: cerr<<"błąd:  nie znaleziono zmiennej "<< index->value <<" : linia "<<index->line<<"\n";
                            error = 1;
                            return code;
                        }
                    }
                    //tablica-argument
                    else{
                        //tablica-argument numer
                        if(index->type == NODE_NUM){
                            code.push_back(std::string("SET ") + index->value);
                            code.push_back("ADD "+ std::to_string(var.memory));
                            code.push_back("LOAD "+ std::to_string(0));
                            code.push_back("PUT "+ std::to_string(0));
                        }
                        else{
                            for(variable in : variables){
                                if(strcmp(in.name, index->value) == 0 ){
                                    //tablica-argument zmienna
                                   if(in.is_arg == 0){
                                        if(in.assign == 1){
                                            code.push_back("LOAD "+ std::to_string(var.memory));
                                            code.push_back("ADD "+ std::to_string(in.memory));
                                            code.push_back("LOADI "+ std::to_string(0));
                                            code.push_back("PUT "+ std::to_string(0));
                                            return code;
                                        }
                                        else{
                                            error = true;
                                            std:: cerr<<"błąd: nie przypisaliśmy wartości do zmiennej "<< var.name << " : linia "<<index->line<<"\n";
                                            return code;
                                        }
                                   } 
                                    //tablica-argument zmienna-argument
                                   else{
                                        code.push_back("LOAD "+ std::to_string(var.memory));
                                        code.push_back("ADDI "+ std::to_string(in.memory));
                                        code.push_back("LOADI "+ std::to_string(0));
                                        code.push_back("PUT "+ std::to_string(0));
                                        return code;
                                   }
                                }
                            }
                            std::cerr<< "błąd:  nie znaleziono zmiennej "<< index->value << " : linia "<< index->line<<"\n";
                            error = 1;
                            return code;   
                        }
                    }
                }
                return code;
            }
        }
        std::cerr << "błąd:  nie znaleziono zmiennej "<< child->value << " : linia "<< child->line<<"\n";
        error = 1;
        return code;
    }
    return code;
}

std::vector<std::string> read(ASTNode* node){
    std::vector<std::string> code;
    ASTNode* child = node->children[0];

    for(variable& var : variables){
        if(strcmp(var.name, child->value) == 0 ){
            if(var.is_itarator == 1){
                std::cerr<<"błąd:  próbujemy zmienić iterator "<< child->value <<" : linia "<<child->line<<"\n";
                error = 1;
                return code;
            }

            var.assign = 1;
            
            //zmienna
            if(var.tab == 0){
                if(child->type == NODE_TAB){
                    std::cerr<<"błąd: to nie jest tablica - "<< child->value <<" : linia "<<child->line<<"\n";
                    error = 1;
                    return code;
                }
                 //zwykła zmienna
                if(var.is_arg == 0){
                    code.push_back("GET "+ std::to_string(var.memory));
                }
                //zmienna-argument
                else{
                    code.push_back("GET "+ std::to_string(0));
                    code.push_back("STOREI "+ std::to_string(var.memory));
                }
            }
            //tablica
            else{
                if(child->children.size() == 0){
                    error = true;
                    std::cerr<<"błąd: nie podano miejsca w tablicy "<< var.name <<" : linia "<<child->line<<"\n";
                    return code;
                }
                ASTNode* index = child->children[0];
                //zwykła tablica
                if(var.is_arg == 0){
                    //tablica numer
                    if(index->type == NODE_NUM){
                        long long num = std::stoll(std::string(index->value));
                        if(num<var.start_index or num > var.end_index){
                            error = true;
                            std::cerr<<"błąd: wychodzimy poza tablice "<< var.name <<" : linia "<<index->line<<"\n";
                            return code;
                        }
                        code.push_back("GET "+ std::to_string(var.memory - var.start_index +  num));
                    }
                    //tablica zmienna
                    else{
                        for(variable in : variables){
                            if(strcmp(in.name, index->value) == 0 ){
                                //tablica zmienna
                               if(in.is_arg == 0){
                                    if(in.assign == 1){
                                        code.push_back("SET "+ std::to_string(var.memory - var.start_index));
                                        code.push_back("ADD "+ std::to_string(in.memory));
                                        memory++;
                                        check_memory();
                                        memory--;
                                        code.push_back("STORE "+ std::to_string(memory + 1));
                                        code.push_back("GET "+ std::to_string(0));
                                        code.push_back("STOREI "+ std::to_string(memory + 1));
                                    }
                                    else{
                                        error = true;
                                        std:: cerr<<"błąd: nie przypisaliśmy wartości do zmiennej "<< in.name << " : linia "<<index->line<<"\n";
                                        return code;
                                    }
                                } 
                               //tablica zmienna-argument
                               else{
                                    code.push_back("SET "+ std::to_string(var.memory - var.start_index));
                                    code.push_back("ADDI "+ std::to_string(in.memory));
                                    memory++;
                                    check_memory();
                                    memory--;
                                    code.push_back("STORE "+ std::to_string(memory + 1));
                                    code.push_back("GET "+ std::to_string(0));
                                    code.push_back("STOREI "+ std::to_string(memory + 1));
                               }
                            }
                            return code;
                        }
                        std::cerr<<"błąd:  nie znaleziono zmiennej "<< index->value <<" : linia "<<index->line<<"\n";
                        error = 1;
                        return code;
                    }
                }
                //tablica-argument
                else{
                    //tablica-argument numer
                    if(index->type == NODE_NUM){
                        code.push_back( std::string("SET ") + index->value);
                        code.push_back("ADD "+ std::to_string(var.memory));
                        memory++;
                        check_memory();
                        memory--;
                        code.push_back("STORE "+ std::to_string(memory + 1));
                        code.push_back("GET "+ std::to_string(0));
                        code.push_back("STOREI "+ std::to_string(memory + 1));
                    }
                    else{
                        for(variable in : variables){
                            if(strcmp(in.name, index->value) == 0 ){
                                //tablica-argument zmienna
                               if(in.is_arg == 0){
                                    if(in.assign == 1){
                                        code.push_back("LOAD "+ std::to_string(var.memory));
                                        code.push_back("ADD "+ std::to_string(in.memory));
                                        memory++;
                                        check_memory();
                                        memory--;
                                        code.push_back("STORE "+ std::to_string(memory + 1));
                                        code.push_back("GET "+ std::to_string(0));
                                        code.push_back("STOREI "+ std::to_string(memory + 1));
                                    }
                                    else{
                                        error = true;
                                        std:: cerr<<"błąd: nie przypisaliśmy wartości do zmiennej "<< in.name << " : linia "<<index->line<<"\n";
                                        return code;
                                    }
                                } 
                                //tablica-argument zmienna-argument
                               else{
                                    code.push_back("LOAD "+ std::to_string(var.memory));
                                    code.push_back("ADDI "+ std::to_string(in.memory));
                                    memory++;
                                    check_memory();
                                    memory--;
                                    code.push_back("STORE "+ std::to_string(memory + 1));
                                    code.push_back("GET "+ std::to_string(0));
                                    code.push_back("STOREI "+ std::to_string(memory + 1));
                               }
                               return code;
                            }
                        }
                        std::cerr<<"błąd:  nie znaleziono zmiennej "<< index->value <<" : linia "<<index->line<<"\n";
                        error = 1;
                        return code;   
                    }
                }
            }
            return code;
        }
    }
    std::cerr<<"błąd:  nie znaleziono zmiennej "<< child->value<<" : linia "<<child->line<<"\n";
    error = 1;
    return code;
}

std::vector<std::string> plus(ASTNode* first, ASTNode* secound){
    std::vector<std::string> code;
    //wartość pierwszej value dajemy do p0 
    //potem dodajemy drugą 
    if(first->type ==   NODE_NUM){
        code.push_back(std::string("SET ") + first->value);
    }
    else if(first->type ==  NODE_VAR){
        variable var = find_var(first->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->value <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd:  nie podano miejsca w tablicy "<< first->value <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }

        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< first->value <<" : linia "<<first->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("LOAD "+ std::to_string(var.memory));
        }
        else{
            code.push_back("LOADI "+ std::to_string(var.memory));
        }
    }
    else{
        variable tab = find_var(first->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->value <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
        if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<first->line<<"\n";
            return code;
        }
        if(first->children[0]->type == NODE_NUM){
            
            if(tab.is_arg == 0){
                if(tab.start_index > std::stoll(std::string(first->children[0]->value)) && tab.end_index < std::stoll(std::string(first->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<first->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(first->children[0]->value))));
            }
            else{
                code.push_back(std::string("SET ") + first->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
        }
        else{
            variable index = find_var(first->children[0]->value);
            if(index.name == nullptr){
                std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->children[0]->value <<" : linia "<<first->children[0]->line<<"\n";
                error = 1;
                return code;
            }
            if(tab.is_arg == 0){
                if(index.is_arg == 0){
                    if(index.assign == 1){
                        code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                        code.push_back("ADD "+ std::to_string(index.memory));
                        code.push_back("LOADI "+ std::to_string(0));
                    }
                    else{
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<first->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                }
                else{
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }
            else{
                if(index.is_arg == 0){
                    if(index.assign == 1){
                        code.push_back("LOAD "+ std::to_string(tab.memory));
                        code.push_back("ADD "+ std::to_string(index.memory));
                        code.push_back("LOADI "+ std::to_string(0));
                    }
                    else{
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<first->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                }
                else{
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }                
        }
    }

    if(secound->type == NODE_NUM){
        memory++;
        check_memory();
        memory--;
        code.push_back("STORE "+ std::to_string(memory + 1));
        code.push_back(std::string("SET ") + secound->value);
        code.push_back("ADD "+ std::to_string(memory + 1));
    }
    else if(secound->type == NODE_VAR){
        variable var = find_var(secound->value);
        if(var.name == nullptr){
            std:: cerr<<"błąd:  nie znaleziono zmiennej "<< secound->value <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd:  nie podano miejsca w tablicy "<< secound->value <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< secound->value <<" : linia "<<secound->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("ADD "+ std::to_string(var.memory));
        }
        else{
            code.push_back("ADDI "+ std::to_string(var.memory));
        }
    }
    else{
        variable tab = find_var(secound->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->value <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<secound->line<<"\n";
            return code;
        }
        if(secound->children[0]->type == NODE_NUM){
            if(tab.is_arg == 0){
                if(tab.start_index > std::stoll(std::string(secound->children[0]->value)) && tab.end_index < std::stoll(std::string(secound->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<secound->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("ADD "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(secound->children[0]->value))));
            }
            else{
                memory++;
                check_memory();
                memory--;
                code.push_back("STORE "+ std::to_string(memory+1));
                code.push_back(std::string("SET ") + secound->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
                code.push_back("ADD "+ std::to_string(memory + 1));
            }
        }
         else{
            variable index = find_var(secound->children[0]->value);
            if(index.name == nullptr){
                std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->children[0]->value <<" : linia "<<secound->children[0]->line<<"\n";
                error = 1;
                return code;
            }
            if(tab.is_arg == 0){
                if(index.is_arg == 0){
                    if(index.assign == 1){
                        memory++;
                        check_memory();
                        memory--;
                        code.push_back("STORE "+ std::to_string(memory+1));
                        code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                        code.push_back("ADD "+ std::to_string(index.memory));
                        code.push_back("LOADI "+ std::to_string(0));
                        code.push_back("ADD "+ std::to_string(memory + 1));
                    }
                    else{
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<secound->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                }
                else{
                    memory++;
                    check_memory();
                    memory--;
                    code.push_back("STORE "+ std::to_string(memory+1));
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("ADD "+ std::to_string(memory + 1));
                }
            }
            else{
                if(index.is_arg == 0){
                    if(index.assign == 1){
                        memory++;
                        check_memory();
                        memory--;
                        code.push_back("STORE "+ std::to_string(memory+1));
                        code.push_back("LOAD "+ std::to_string(tab.memory));
                        code.push_back("ADD "+ std::to_string(index.memory));
                        code.push_back("LOADI "+ std::to_string(0));
                        code.push_back("ADD "+ std::to_string(memory + 1));
                    } 
                     else{
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<secound->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                }
                else{
                    memory++;
                    check_memory();
                    memory--;
                    code.push_back("STORE "+ std::to_string(memory+1));
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("ADD "+ std::to_string(memory + 1));
                }
            }                
        }
    }
    return code;
}

std::vector<std::string> minus(ASTNode* first, ASTNode* secound){
    std::vector<std::string> code;
    //wartość pierwszej value dajemy do p0 
    //potem odejmujemy drugą 
    if(first->type ==   NODE_NUM){
        code.push_back(std::string("SET ") + first->value);
    }
    else if(first->type ==  NODE_VAR){
        variable var = find_var(first->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->value << " : linia " <<first->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< first->value <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< first->value <<" : linia "<<first->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("LOAD "+ std::to_string(var.memory));
        }
        else{
            code.push_back("LOADI "+ std::to_string(var.memory));
        }
    }
    else{
        variable tab = find_var(first->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->value <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
        if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<first->line<<"\n";
            return code;
        }

        if(first->children[0]->type == NODE_NUM){
            if(tab.is_arg == 0){
                if(tab.start_index > std::stoll(std::string(first->children[0]->value)) && tab.end_index < std::stoll(std::string(first->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<first->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(first->children[0]->value))));
            }
            else{
                code.push_back(std::string("SET ") + first->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
        }
        else{
            variable index = find_var(first->children[0]->value);
            if(index.name == nullptr){
                std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->children[0]->value <<" : linia "<<first->children[0]->line<<"\n";
                error = 1;
                return code;
            }
            if(tab.is_arg == 0){
                if(index.is_arg == 0){
                    if(index.assign == 1){
                        code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                        code.push_back("ADD "+ std::to_string(index.memory));
                        code.push_back("LOADI "+ std::to_string(0));
                    } 
                    else{
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<first->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                }
                else{
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }
            else{
                if(index.is_arg == 0){
                    if(index.assign == 1){
                        code.push_back("LOAD "+ std::to_string(tab.memory));
                        code.push_back("ADD "+ std::to_string(index.memory));
                        code.push_back("LOADI "+ std::to_string(0));
                    }
                    else{
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<first->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                }
                else{
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }                
        }
    }
    if(secound->type == NODE_NUM){
        memory +=2;
        check_memory();
        memory-=2;
        code.push_back("STORE "+ std::to_string(memory + 1));
        code.push_back(std::string("SET ") + secound->value);
        code.push_back("STORE "+ std::to_string(memory + 2));
        code.push_back("LOAD "+ std::to_string(memory + 1));
        code.push_back("SUB "+ std::to_string(memory + 2));
    }
    else if(secound->type == NODE_VAR){
        variable var = find_var(secound->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->value <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< secound->value <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< secound->value <<" : linia "<<secound->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("SUB "+ std::to_string(var.memory));
        }
        else{
            code.push_back("SUBI "+ std::to_string(var.memory));
        }
    }
    else{
        variable tab = find_var(secound->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->value <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<secound->line<<"\n";
            return code;
        }
        if(secound->children[0]->type == NODE_NUM){
            if(tab.is_arg == 0){
                if(tab.start_index > std::stoll(std::string(secound->children[0]->value)) && tab.end_index < std::stoll(std::string(secound->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<secound->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("SUB "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(secound->children[0]->value))));
            }
            else{
                 memory +=2;
                check_memory();
                memory-=2;
                code.push_back("STORE "+ std::to_string(memory+1));
                code.push_back(std::string("SET ") + secound->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
                code.push_back("STORE "+ std::to_string(memory+2));
                code.push_back("LOAD "+ std::to_string(memory+1));
                code.push_back("SUB "+ std::to_string(memory + 2));
            }
        }
        else{
            variable index = find_var(secound->children[0]->value);
            if(index.name == nullptr){
                std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->children[0]->value <<" : linia "<<secound->children[0]->line<<"\n";
                error = 1;
                return code;
            }
            if(tab.is_arg == 0){
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<secound->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                     memory +=2;
                    check_memory();
                    memory-=2;
                    code.push_back("STORE "+ std::to_string(memory+1));
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("STORE "+ std::to_string(memory+2));
                    code.push_back("LOAD "+ std::to_string(memory + 1));
                    code.push_back("SUBI "+ std::to_string(memory + 2));
                }
                else{
                     memory +=2;
                    check_memory();
                    memory-=2;
                    code.push_back("STORE "+ std::to_string(memory+1));
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("STORE "+ std::to_string(memory+2));
                    code.push_back("LOAD "+ std::to_string(memory + 1));
                    code.push_back("SUBI "+ std::to_string(memory + 2));
                }
            }
            else{
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<secound->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                     memory +=2;
                    check_memory();
                    memory-=2;
                    code.push_back("STORE "+ std::to_string(memory+1));
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("STORE "+ std::to_string(memory+2));
                    code.push_back("LOAD "+ std::to_string(memory + 1));
                    code.push_back("SUBI "+ std::to_string(memory + 2));
                }
                else{
                     memory +=2;
                    check_memory();
                    memory-=2;
                    code.push_back("STORE "+ std::to_string(memory+1));
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("STORE "+ std::to_string(memory+2));
                    code.push_back("LOAD "+ std::to_string(memory + 1));
                    code.push_back("SUBI "+ std::to_string(memory + 2));
                }
            }                
        }
    }
    return code;
}


std::vector<std::string> multipy(ASTNode* first, ASTNode* secound){
    std::vector<std::string> code;
    //algorytm mnożenia rosyjskich chłopów 
    //w przypadku liczb ujemnych biezrzemy ich wartość bezwzględną a potem dostosujemy wynik

    /* 
    wartość pierwsza memory +1 
    wartość druga memeory + 2
    wartość wyniku memory + 3
    znak wyniku memory + 4 - 0 - dodatni, -1 - ujemny
    */
    memory +=4;
    check_memory();
    memory-=4;
    //ustawiamy znak wyniku na dodatni 
    code.push_back("SET 0");
    code.push_back("STORE "+ std::to_string(memory + 4));

    //wstawiamy wartość pierwszą do p0
    if(first->type ==   NODE_NUM){
        code.push_back(std::string("SET ") + first->value);    
    }
    else if(first->type ==  NODE_VAR){
        variable var = find_var(first->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->value  <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< first->value <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< first->value <<" : linia "<<first->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("LOAD "+ std::to_string(var.memory));
        }
        else{
            code.push_back("LOADI "+ std::to_string(var.memory));
        }
    }
    else{
        variable tab = find_var(first->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->value  <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
         if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<first->line<<"\n";
            return code;
        }
        if(first->children[0]->type == NODE_NUM){
            if(tab.is_arg == 0){
                if(tab.start_index > std::stoll(std::string(first->children[0]->value)) && tab.end_index < std::stoll(std::string(first->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<first->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(first->children[0]->value))));
            }
            else{
                code.push_back(std::string("SET ") + first->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
        }
        else{
            variable index = find_var(first->children[0]->value);
            if(index.name == nullptr){
                std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->children[0]->value  <<" : linia "<<first->children[0]->line<<"\n";
                error = 1;
                return code;
            }
            if(tab.is_arg == 0){
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<first->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
                else{
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }
            else{
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<first->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
                else{
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }                
        }
    }
    //zapisujemy wartość bezwzględną pierwszej wartości w memory + 1 i ustawiamy odpowiedni znak wyniku
    code.push_back("STORE "+ std::to_string(memory+1));
    code.push_back("JNEG "+ std::to_string(2));
    code.push_back("JUMP "+ std::to_string(7));
    code.push_back("SUB "+ std::to_string(memory+1));
    code.push_back("SUB "+ std::to_string(memory+1));
    code.push_back("STORE "+ std::to_string(memory+1));

    code.push_back("SET -1");
    code.push_back("SUB "+ std::to_string(memory+4));
    code.push_back("STORE "+ std::to_string(memory+4));

    //to samo dla drugiej wartości
    if(secound->type ==   NODE_NUM){
        code.push_back(std::string("SET ") + secound->value);    
    }
    else if(secound->type ==  NODE_VAR){
        variable var = find_var(secound->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->value  <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< secound->value <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< secound->value <<" : linia "<<secound->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("LOAD "+ std::to_string(var.memory));
        }
        else{
            code.push_back("LOADI "+ std::to_string(var.memory));
        }
    }
    else{
        variable tab = find_var(secound->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->value  <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
         if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<secound->line<<"\n";
            return code;
        }
        if(secound->children[0]->type == NODE_NUM){
            if(tab.is_arg == 0){
                if(tab.start_index > std::stoll(std::string(secound->children[0]->value)) && tab.end_index < std::stoll(std::string(secound->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<secound->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(secound->children[0]->value))));
            }
            else{
                code.push_back(std::string("SET ") + secound->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
        }
        else{
            variable index = find_var(secound->children[0]->value);
            if(index.name == nullptr){
                std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->children[0]->value  <<" : linia "<<secound->children[0]->line<<"\n";
                error = 1;
                return code;
            }
            if(tab.is_arg == 0){
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<secound->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
                else{
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }
            else{
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<secound->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
                else{
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }                
        }
    }
    code.push_back("STORE "+ std::to_string(memory+2));
    code.push_back("JNEG "+ std::to_string(2));
    code.push_back("JUMP "+ std::to_string(7));
    code.push_back("SUB "+ std::to_string(memory+2));
    code.push_back("SUB "+ std::to_string(memory+2));
    code.push_back("STORE "+ std::to_string(memory+2));

    code.push_back("SET -1");
    code.push_back("SUB "+ std::to_string(memory+4));
    code.push_back("STORE "+ std::to_string(memory+4));

    //początkowo wynik = 0
    code.push_back("SET 0");
    code.push_back("STORE "+ std::to_string(memory+3));

    //sprawdzamy czy b-parzyste i jeśli nie to dodajemy a do wyniku
    code.push_back("LOAD "+ std::to_string(memory+2));
    code.push_back("HALF");
    code.push_back("ADD "+ std::to_string(0));
    code.push_back("SUB "+ std::to_string(memory+2));
    code.push_back("JZERO "+ std::to_string(4));
    code.push_back("LOAD "+ std::to_string(memory+3));
    code.push_back("ADD "+ std::to_string(memory+1));
    code.push_back("STORE "+ std::to_string(memory+3));

    //mnożymy a*2 i dzielimy b/2
    code.push_back("LOAD "+ std::to_string(memory+1));
    code.push_back("ADD "+ std::to_string(memory+1));
    code.push_back("STORE "+ std::to_string(memory+1));

    code.push_back("LOAD "+ std::to_string(memory+2));
    code.push_back("HALF");
    code.push_back("STORE "+ std::to_string(memory+2));

    //jeśli b = 0 to koniec, w p. p. wróć na początek algorytmu
    code.push_back("JZERO "+ std::to_string(2));
    code.push_back("JUMP -"+ std::to_string(15));

    //ustawiamy odpowiedni znak wyniku
    code.push_back("LOAD "+ std::to_string(memory+4));
    code.push_back("JZERO "+ std::to_string(5));
    code.push_back("LOAD "+ std::to_string(memory + 3));
    code.push_back("SUB "+ std::to_string(memory + 3));
    code.push_back("SUB "+ std::to_string(memory + 3));
    code.push_back("STORE "+ std::to_string(memory + 3));

    //wynik do p0
    code.push_back("LOAD "+ std::to_string(memory + 3));

    return code;
}

std::vector<std::string> div(ASTNode* first, ASTNode* secound, bool modulo){
    std::vector<std::string> code;
    //w przypadku liczb ujemnych biezrzemy ich wartość bezwzględną a potem dostosujemy wynik

    /* 
    wartość pierwsza memory +1 
    wartość druga memeory + 2
    temp1 memory +1 
    temp2 memeory + 2
    znak pierwszej memory + 5 - 0 - dodatni, -1 - ujemny
    znak drugiej memory + 6 - 0 - dodatni, -1 - ujemny
    wartość dzielenia memory + 7
    wartość modulo memory + 8
    */

    memory +=8;
    check_memory();
    memory-=8;

    //ustawiamy znaki liczb na dodatnie
    code.push_back("SET 0");
    code.push_back("STORE "+ std::to_string(memory + 5));
    code.push_back("STORE "+ std::to_string(memory + 6));

    //wstawiamy wartość pierwszą do p0
    if(first->type ==   NODE_NUM){
        code.push_back(std::string("SET ") + first->value);    
    }
    else if(first->type ==  NODE_VAR){
        variable var = find_var(first->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->value  <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< first->value <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< first->value <<" : linia "<<first->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("LOAD "+ std::to_string(var.memory));
        }
        else{
            code.push_back("LOADI "+ std::to_string(var.memory));
        }
    }
    else{
        variable tab = find_var(first->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->value  <<" : linia "<<first->line<<"\n";
            error = 1;
            return code;
        }
        if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<first->line<<"\n";
            return code;
        }

        if(first->children[0]->type == NODE_NUM){
            if(tab.is_arg == 0){
                if(tab.start_index > std::stoll(std::string(first->children[0]->value)) && tab.end_index < std::stoll(std::string(first->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<first->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(first->children[0]->value))));
            }
            else{
                code.push_back(std::string("SET ") + first->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
        }
        else{
            variable index = find_var(first->children[0]->value);
            if(index.name == nullptr){
                std::cerr<<"błąd:  nie znaleziono zmiennej "<< first->children[0]->value  <<" : linia "<<first->children[0]->line<<"\n";
                error = 1;
                return code;
            }
            if(tab.is_arg == 0){
                if(index.is_arg == 0){
                     if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<first->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
                else{
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }
            else{
                if(index.is_arg == 0){
                     if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<first->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
                else{
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }                
        }
    }
    //zapisujemy wartość bezwzględną pierwszej wartości w memory + 1 i ustawiamy odpowiedni znak 
    code.push_back("STORE "+ std::to_string(memory+1));
    code.push_back("JNEG "+ std::to_string(2));
    code.push_back("JUMP "+ std::to_string(6));
    code.push_back("SUB "+ std::to_string(memory+1));
    code.push_back("SUB "+ std::to_string(memory+1));
    code.push_back("STORE "+ std::to_string(memory+1));

    code.push_back("SET -1");
    code.push_back("STORE "+ std::to_string(memory+5));

    //to samo dla drugiej wartości
    if(secound->type ==   NODE_NUM){
        code.push_back(std::string("SET ") + secound->value);    
    }
    else if(secound->type ==  NODE_VAR){
        variable var = find_var(secound->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->value  <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< secound->value <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< secound->value <<" : linia "<<secound->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("LOAD "+ std::to_string(var.memory));
        }
        else{
            code.push_back("LOADI "+ std::to_string(var.memory));
        }
    }
    else{
        variable tab = find_var(secound->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->value <<" : linia "<<secound->line<<"\n";
            error = 1;
            return code;
        }
         if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<secound->line<<"\n";
            return code;
        }

        if(secound->children[0]->type == NODE_NUM){
            if(tab.is_arg == 0){
                if(tab.start_index > std::stoll(std::string(secound->children[0]->value)) && tab.end_index < std::stoll(std::string(secound->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<secound->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(secound->children[0]->value))));
            }
            else{
                code.push_back(std::string("SET ") + secound->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
        }
        else{
            variable index = find_var(secound->children[0]->value);
            if(index.name == nullptr){
                std::cerr<<"błąd:  nie znaleziono zmiennej "<< secound->children[0]->value  <<" : linia "<<secound->children[0]->line<<"\n";
                error = 1;
                return code;
            }
            if(tab.is_arg == 0){
                if(index.is_arg == 0){
                     if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<secound->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
                else{
                    code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }
            else{
                if(index.is_arg == 0){
                     if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<secound->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
                else{
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                }
            }                
        }
    }
    code.push_back("STORE "+ std::to_string(memory+2));
    code.push_back("JNEG "+ std::to_string(2));
    code.push_back("JUMP "+ std::to_string(6));
    code.push_back("SUB "+ std::to_string(memory+2));
    code.push_back("SUB "+ std::to_string(memory+2));
    code.push_back("STORE "+ std::to_string(memory+2));

    code.push_back("SET -1");
    code.push_back("STORE "+ std::to_string(memory+6));

    //jeśli b = 0 to zwracamy 0 
    code.push_back("LOAD "+ std::to_string(memory+2));
    code.push_back("JZERO 2");
    code.push_back("JUMP 3");
    code.push_back("SET "+ std::to_string(0));
    code.push_back("JUMP 85");

    //początkowo temp1 = 1, temp2 = b
    code.push_back("SET 1");
    code.push_back("STORE "+ std::to_string(memory+3));
    code.push_back("LOAD "+ std::to_string(memory+2));
    code.push_back("STORE "+ std::to_string(memory+4));

    //algorytm dzielenia
    
    //if(b<=a) algorytm else{wynik = 0 modulo a}
    code.push_back("LOAD "+ std::to_string(memory+2));
    code.push_back("SUB "+ std::to_string(memory+1));
    code.push_back("JPOS "+ std::to_string(54));

    //znajdujemy największe temp2 - potęga b
    //while
    //condition
    code.push_back("LOAD "+ std::to_string(memory+4));
    code.push_back("SUB "+ std::to_string(memory+1));
    code.push_back("JNEG "+ std::to_string(2));
    code.push_back("JUMP "+ std::to_string(8));

    //polecenia
    code.push_back("LOAD "+ std::to_string(memory + 3));
    code.push_back("ADD "+ std::to_string(memory + 3));
    code.push_back("STORE "+ std::to_string(memory + 3));

    code.push_back("LOAD "+ std::to_string(memory + 4));
    code.push_back("ADD "+ std::to_string(memory + 4));
    code.push_back("STORE "+ std::to_string(memory + 4));

    code.push_back("JUMP -"+ std::to_string(10));
    
    //if
    //condition
    code.push_back("LOAD "+ std::to_string(memory+4));
    code.push_back("SUB "+ std::to_string(memory+1));
    code.push_back("JPOS "+ std::to_string(2));
    code.push_back("JUMP "+ std::to_string(7));

    //polecenia
    code.push_back("LOAD "+ std::to_string(memory + 3));
    code.push_back("HALF");
    code.push_back("STORE "+ std::to_string(memory + 3));

    code.push_back("LOAD "+ std::to_string(memory + 4));
    code.push_back("HALF");
    code.push_back("STORE "+ std::to_string(memory + 4));

    //po if
    code.push_back("LOAD "+ std::to_string(memory + 1));
    code.push_back("SUB "+ std::to_string(memory + 4));
    code.push_back("STORE "+ std::to_string(memory + 1));

    code.push_back("LOAD "+ std::to_string(memory + 3));
    code.push_back("STORE "+ std::to_string(memory + 7));

    //główna pętla
    code.push_back("LOAD "+ std::to_string(memory+3));
    code.push_back("JPOS "+ std::to_string(2));
    code.push_back("JUMP "+ std::to_string(19));

    //polecenia
    //while
    code.push_back("LOAD "+ std::to_string(memory+4));
    code.push_back("SUB "+ std::to_string(memory+1));
    code.push_back("JPOS "+ std::to_string(2));
    code.push_back("JUMP "+ std::to_string(8));

    //polecenia
    code.push_back("LOAD "+ std::to_string(memory + 3));
    code.push_back("HALF");
    code.push_back("STORE "+ std::to_string(memory + 3));

    code.push_back("LOAD "+ std::to_string(memory + 4));
    code.push_back("HALF");
    code.push_back("STORE "+ std::to_string(memory + 4));

    code.push_back("JUMP -"+ std::to_string(10));

    code.push_back("LOAD "+ std::to_string(memory + 7));
    code.push_back("ADD "+  std::to_string(memory + 3));
    code.push_back("STORE "+ std::to_string(memory + 7));

    code.push_back("LOAD "+ std::to_string(memory + 1));
    code.push_back("SUB "+  std::to_string(memory + 4));
    code.push_back("STORE "+ std::to_string(memory + 1));

    code.push_back("JUMP -"+ std::to_string(20));

    code.push_back("LOAD "+ std::to_string(memory + 1));
    code.push_back("ADD "+  std::to_string(memory + 4));
    code.push_back("STORE "+ std::to_string(memory + 1));

    code.push_back("LOAD "+ std::to_string(memory + 1));
    code.push_back("STORE "+ std::to_string(memory + 8));

    //else
    code.push_back("JUMP "+ std::to_string(5));

    code.push_back("SET 0");
    code.push_back("STORE "+ std::to_string(memory+7));

    code.push_back("LOAD "+ std::to_string(memory + 1));
    code.push_back("STORE "+ std::to_string(memory + 8));

    //wynik ujemny 
    code.push_back("LOAD "+ std::to_string(memory + 5));
    code.push_back("SUB "+  std::to_string(memory + 6));
    code.push_back("JZERO "+ std::to_string(12));

    code.push_back("SET 0");
    code.push_back("SUB "+  std::to_string(memory + 7));
    code.push_back("STORE "+ std::to_string(memory + 7));

    code.push_back("LOAD "+ std::to_string(memory + 8));
    code.push_back("JZERO "+ std::to_string(7));

    code.push_back("SET -1");
    code.push_back("ADD "+  std::to_string(memory + 7));
    code.push_back("STORE "+ std::to_string(memory + 7));
    code.push_back("LOAD "+ std::to_string(memory + 2));
    code.push_back("SUB "+  std::to_string(memory + 8));
    code.push_back("STORE "+ std::to_string(memory + 8));

    //znak modulo
    code.push_back("LOAD "+ std::to_string(memory + 6));
    code.push_back("JZERO "+ std::to_string(4));
    code.push_back("SET "+ std::to_string(0));
    code.push_back("SUB "+  std::to_string(memory + 8));
    code.push_back("STORE "+ std::to_string(memory + 8));

    //wynik do p0 jeśli mod to mod jesli nie to dzielenie
    if(modulo == 0){
        code.push_back("LOAD "+ std::to_string(memory + 7));
    }
    else{
        code.push_back("LOAD "+ std::to_string(memory + 8));
    }

    return code;
}

std::vector<std::string> expression(ASTNode* node){
    std::vector<std::string> code;
    if(node->type == NODE_NUM){
        code.push_back(std::string("SET ") + node->value);
    }
    else if(node->type == NODE_VAR){
        variable var = find_var(node->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< node->value  <<" : linia "<<node->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< node->value <<" : linia "<<node->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< node->value <<" : linia "<<node->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("LOAD "+ std::to_string(var.memory));
        }
        else{
            code.push_back("LOADI "+ std::to_string(var.memory));
        }
    }
    else if(node->type == NODE_TAB){
        //tablica numer - done
        //tablica-argument numer - done
        //tablica zmienna - done
        //tablica zmienna-argument - done
        //tablica-argument zmienna - done
        //tablica-argument zmienna-argument - done
        variable tab = find_var(node->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< node->value  <<" : linia "<<node->line<<"\n";
            error = 1;
            return code;
        }
        if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<node->line<<"\n";
            return code;
        }
        if(node->children[0]->type == NODE_NUM){
            if(tab.is_arg == 0){
                if(tab.start_index > std::stoll(std::string(node->children[0]->value)) && tab.end_index < std::stoll(std::string(node->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<node->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(node->children[0]->value))));
                return code;
            }
            else{
                code.push_back(std::string("SET ") + node->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
                return code;
            }
        }
        variable index = find_var(node->children[0]->value);
        if(index.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< node->children[0]->value <<" : linia "<<node->children[0]->line<<"\n";
            error = 1;
            return code;
        }
        if(tab.is_arg == 0){
            if(index.is_arg == 0){
                if(index.assign == 0){
                    std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<node->children[0]->line<<"\n";
                    error = 1;
                    return code;
                }
                code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                code.push_back("ADD "+ std::to_string(index.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
            else{
                code.push_back("SET " + std::to_string(tab.memory - tab.start_index));
                code.push_back("ADDI "+ std::to_string(index.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
        }
        else{
            if(index.is_arg == 0){
                if(index.assign == 0){
                    std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<node->children[0]->line<<"\n";
                    error = 1;
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory));
                code.push_back("ADD "+ std::to_string(index.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
            else{
                code.push_back("LOAD "+ std::to_string(tab.memory));
                code.push_back("ADDI "+ std::to_string(index.memory));
                code.push_back("LOADI "+ std::to_string(0));
            }
        }
        
    }
    //(node->type == NODE_ARITHMETIC)
    else {
        if(strcmp(node->value, "+") == 0){
           code = plus(node->children[0], node->children[1]);
        }
        else if(strcmp(node->value, "-") == 0){
            code = minus(node->children[0], node->children[1]);
        }
        else if(strcmp(node->value, "*") == 0){
            code = multipy(node->children[0], node->children[1]);  
        }
        else if(strcmp(node->value, "/") == 0){
            code = div(node->children[0], node->children[1], 0);
        }
        else if(strcmp(node->value, "%") == 0){
            code = div(node->children[0], node->children[1], 1);
        }
    }
    return code;
}

std::vector<std::string> assign(ASTNode* node){
    std::vector<std::string> code;
    /* child[0] = id, child[1] = expression
    mamy id := expression
    zróbmy tak że expression zwraca wartość do p0
    wtedy id przypisuje wartość z p0 i nie patrzy na to czy jest to działanie czy zmienna bądź numer
    wtedy na początku wywołamy działanie które sparwdzi co to jest i wstawi wynik do p0 - std::vector<std::string> expression(ASTNode* node)
    potem wstawimy wartość z p0 do id
    */
    ASTNode* id = node->children[0];
    ASTNode* expr = node->children[1];
    code = expression(expr);

    //przypisanie id wartości z p0
    if(id->type == NODE_VAR){
        variable var = find_var(id->value, 1);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< id->value  <<" : linia "<<id->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_itarator == 1){
            std::cerr<<"błąd:  próbujemy zmienić iterator "<< id->value  <<" : linia "<<id->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< id->value <<" : linia "<<id->line<<"\n";
            error = 1;
            return code;
        }

        if(var.is_arg==0){
            code.push_back("STORE "+ std::to_string(var.memory));
        }
        else{
            code.push_back("STOREI "+ std::to_string(var.memory));
        }
    }
    else{
        variable var = find_var(id->value, 1);
        if(var.name == nullptr){
           std::cerr<<"błąd:  nie znaleziono zmiennej "<< id->value  <<" : linia "<<id->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< var.name <<" : linia "<<id->line<<"\n";
            return code;
        }
        ASTNode* index = id->children[0];
            //tablica numer - done
            //tablica-argument numer - done
            //tablica zmienna - done
            //tablica zmienna-argument - done
            //tablica-argument zmienna - done
            //tablica-argument zmienna-argument - done
        if(var.is_arg == 0){
            if(index->type == NODE_NUM){
                if(var.start_index > std::stoll(std::string(index->value)) && var.end_index < std::stoll(std::string(index->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< var.name <<" : linia "<<index->line<<"\n";
                    return code;
                }
                code.push_back("STORE "+ std::to_string(var.memory - var.start_index + std::stoll(std::string(index->value))));
            }
            else {
                variable index_var = find_var(index->value);
                if(index_var.name == nullptr){
                    std::cerr<<"błąd:  nie znaleziono zmiennej "<<index->value  <<" : linia "<<index->line<<"\n";
                    error = 1;
                    return code;
                }
                if(index_var.is_arg == 0){
                    if(index_var.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index_var.name <<" : linia "<<index->line<<"\n";
                        error = 1;
                        return code;
                    }
                    memory +=2;
                    check_memory();
                    memory-=2;
                    code.push_back("STORE "+ std::to_string(memory + 1));
                    code.push_back("SET " + std::to_string(var.memory - var.start_index));
                    code.push_back("ADD "+ std::to_string(index_var.memory));
                    code.push_back("STORE "+ std::to_string(memory + 2));
                    code.push_back("LOAD "+ std::to_string(memory + 1));
                    code.push_back("STOREI "+ std::to_string(memory + 2));
                }
                else{
                    memory +=2;
                    check_memory();
                    memory-=2;
                    code.push_back("STORE "+ std::to_string(memory + 1));
                    code.push_back("SET " + std::to_string(var.memory - var.start_index));
                    code.push_back("ADDI "+ std::to_string(index_var.memory));
                    code.push_back("STORE "+ std::to_string(memory + 2));
                    code.push_back("LOAD "+ std::to_string(memory + 1));
                    code.push_back("STOREI "+ std::to_string(memory + 2));
                }
            }
        }
        else{
            if(index->type == NODE_NUM){
                memory +=2;
                check_memory();
                memory-=2;
                code.push_back("STORE "+ std::to_string(memory + 1));
                code.push_back(std::string("SET ") + index->value);
                code.push_back("ADD "+ std::to_string(var.memory));
                code.push_back("STORE "+ std::to_string(memory + 2));
                code.push_back("LOAD "+ std::to_string(memory + 1));
                code.push_back("STOREI "+ std::to_string(memory + 2));
            }
            else {
                variable index_var = find_var(index->value);
                if(index_var.name == nullptr){
                    std::cerr<<"błąd:  nie znaleziono zmiennej "<< index->value  <<" : linia "<<index->line<<"\n";
                    error = 1;
                    return code;
                }
                if(index_var.is_arg == 0){
                    if(index_var.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index_var.name <<" : linia "<<index->line<<"\n";
                        error = 1;
                        return code;
                    }
                    memory +=2;
                    check_memory();
                    memory-=2;
                    code.push_back("STORE "+ std::to_string(memory + 1));
                    code.push_back("LOAD " + std::to_string(var.memory));
                    code.push_back("ADD "+ std::to_string(index_var.memory));
                    code.push_back("STORE "+ std::to_string(memory + 2));
                    code.push_back("LOAD "+ std::to_string(memory + 1));
                    code.push_back("STOREI "+ std::to_string(memory + 2));
                }
                else{
                    memory +=2;
                    check_memory();
                    memory-=2;
                    code.push_back("STORE "+ std::to_string(memory + 1));
                    code.push_back("LOAD " + std::to_string(var.memory));
                    code.push_back("ADDI "+ std::to_string(index_var.memory));
                    code.push_back("STORE "+ std::to_string(memory + 2));
                    code.push_back("LOAD "+ std::to_string(memory + 1));
                    code.push_back("STOREI "+ std::to_string(memory + 2));
                }
            }
        }
    }
    return code;
}
std::vector<std::string> output(ASTNode* node);

std::vector<std::string> if_code(ASTNode* if_node){
    std::vector<std::string> code;

    ASTNode* condition = if_node->children[0];
    ASTNode* if_commands = if_node->children[1];

    ASTNode* else_commands = nullptr;
    if(if_node->children.size()==3){
        else_commands = if_node->children[2];
    }

    //sprawdzenie warunku i skok - skok o if_com.size() + 1 lub jeśli jest else to o if_com.size() + 2
    code = minus(condition->children[0], condition->children[1]);

    std::vector<std::string> if_com = output(if_commands); //komendy z if

    long long jump = if_com.size() + 1;
    if(else_commands != nullptr){
        jump ++;
    }

    if(strcmp(condition->value, "=") == 0){
        code.push_back("JZERO "+ std::to_string(2));
        code.push_back("JUMP "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, "!=") == 0){
        code.push_back("JZERO "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, ">") == 0){
        code.push_back("JPOS "+ std::to_string(2));
        code.push_back("JUMP "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, "<=") == 0){
        code.push_back("JPOS "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, "<") == 0){
        code.push_back("JNEG "+ std::to_string(2));
        code.push_back("JUMP "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, ">=") == 0){
        code.push_back("JNEG "+ std::to_string(jump));
    }


    for(std::string s : if_com){
        code.push_back(s);
    }
    //jeśli else!=nullptr to skok za else
    if(else_commands != nullptr){
        //komendy z else 
        std::vector<std::string> else_com = output(else_commands);

        code.push_back("JUMP "+ std::to_string(else_com.size()+1));
        
        for(std::string s : else_com){
            code.push_back(s);
        }
    }
    return code;
}

std::vector<std::string> while_code(ASTNode* while_node){
    std::vector<std::string> code;

    ASTNode* condition = while_node->children[0];
    ASTNode* while_commands = while_node->children[1];

    //sprawdzenie warunku i skok jeśli zachodzi
    code = minus(condition->children[0], condition->children[1]);

    std::vector<std::string> while_com = output(while_commands); 

    long long jump = while_com.size() + 2;

    if(strcmp(condition->value, "=") == 0){
        code.push_back("JZERO "+ std::to_string(2));
        code.push_back("JUMP "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, "!=") == 0){
        code.push_back("JZERO "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, ">") == 0){
        code.push_back("JPOS "+ std::to_string(2));
        code.push_back("JUMP "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, "<=") == 0){
        code.push_back("JPOS "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, "<") == 0){
        code.push_back("JNEG "+ std::to_string(2));
        code.push_back("JUMP "+ std::to_string(jump));
    }
    else if(strcmp(condition->value, ">=") == 0){
        code.push_back("JNEG "+ std::to_string(jump));
    }

    for(std::string s : while_com){
        code.push_back(s);
    }
    //wróć na początek while
    code.push_back("JUMP -"+ std::to_string(code.size()));

    return code;
}

std::vector<std::string> repeat(ASTNode* repeat_node){
    std::vector<std::string> code;

    ASTNode* condition = repeat_node->children[1];
    ASTNode* repeat_commands = repeat_node->children[0];

    code = output(repeat_commands); 

    //sprawdzenie warunku i skok jeśli nie zachodzi
    std::vector<std::string> con = minus(condition->children[0], condition->children[1]);
    for(std::string s : con){
        code.push_back(s);
    }

    long long jump = code.size() + 1;

    if(strcmp(condition->value, "=") == 0){
        code.push_back("JZERO "+ std::to_string(2));
        code.push_back("JUMP -"+ std::to_string(jump));
    }
    else if(strcmp(condition->value, "!=") == 0){
        code.push_back("JZERO -"+ std::to_string(jump-1));
    }
    else if(strcmp(condition->value, ">") == 0){
        code.push_back("JPOS "+ std::to_string(2));
        code.push_back("JUMP -"+ std::to_string(jump));
    }
    else if(strcmp(condition->value, "<=") == 0){
        code.push_back("JPOS -"+ std::to_string(jump-1));
    }
    else if(strcmp(condition->value, "<") == 0){
        code.push_back("JNEG "+ std::to_string(2));
        code.push_back("JUMP -"+ std::to_string(jump));
    }
    else if(strcmp(condition->value, ">=") == 0){
        code.push_back("JNEG -"+ std::to_string(jump-1));
    }

    return code;
}
void remove_variable(const char* variable_name) {
    // Usunięcie zmiennej z wektora
    variables.erase(
        std::remove_if(
            variables.begin(), 
            variables.end(),
            [variable_name](const variable& var) {
                return strcmp(var.name, variable_name) == 0; 
            }
        ),
        variables.end()
    );
}
std::vector<std::string> for_code(ASTNode* for_node, bool is_downto){
    std::vector<std::string> code;

    // tworzymy variable iterator, która przyjmuje wartość for_node->children[0]
    if(!check_var(for_node->value)){
        std::cerr<<"błąd:  już istnieje taka zmienna - problem z iteratorem "<< for_node->value  <<" : linia "<<for_node->line<<"\n";
        error = 1;
        return code;
    }
    variable iterator;
    iterator.is_itarator = 1;
    iterator.is_arg = 0;
    iterator.tab = 0;
    iterator.assign = 1;
    iterator.name = for_node->value;
    check_memory();
    iterator.memory = memory +1;
    memory++;
    check_memory();
    variables.push_back(iterator);

    ASTNode* start = for_node->children[0];

    if(start->type == NODE_NUM){
        code.push_back(std::string("SET ") + start->value);
        code.push_back("STORE "+ std::to_string(iterator.memory));
    }
    else if(start->type == NODE_VAR){
        variable var = find_var(start->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< start->value <<" : linia "<<start->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< start->value <<" : linia "<<start->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< start->value <<" : linia "<<start->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("LOAD "+ std::to_string(var.memory));
            code.push_back("STORE "+ std::to_string(iterator.memory));
        }
        else{
            code.push_back("LOADI "+ std::to_string(var.memory));
            code.push_back("STORE "+ std::to_string(iterator.memory));
        }
    }
    else{
        variable tab = find_var(start->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< start->value <<" : linia "<<start->line<<"\n";
            error = 1;
            return code;
        }
        if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<start->line<<"\n";
            return code;
        }

        if(tab.is_arg == 0){
            if(start->children[0]->type == NODE_NUM){
                if(tab.start_index > std::stoll(std::string(start->children[0]->value)) && tab.end_index < std::stoll(std::string(start->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<start->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory - tab.start_index + std::stoll(std::string(start->children[0]->value))));
                code.push_back("STORE "+ std::to_string(iterator.memory));
            }
            else if(start->children[0]->type == NODE_VAR){
                variable index = find_var(start->children[0]->value);
                if(index.name == nullptr){
                    std::cerr<<"błąd:  nie znaleziono zmiennej "<< start->children[0]->value <<" : linia "<<start->children[0]->line<<"\n";
                    error = 1;
                    return code;
                }
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<start->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("SET "+ std::to_string(tab.memory));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("STORE "+ std::to_string(iterator.memory));
                }
                else{
                    code.push_back("SET "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("STORE "+ std::to_string(iterator.memory));
                }
            }
        }
        else{
            if(start->children[0]->type == NODE_NUM){
                code.push_back(std::string("SET ") + start->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
                code.push_back("STORE "+ std::to_string(iterator.memory));
            }
            else if(start->children[0]->type == NODE_VAR){
                variable index = find_var(start->children[0]->value);
                if(index.name == nullptr){
                    std::cerr<<"błąd:  nie znaleziono zmiennej "<< start->children[0]->value <<" : linia "<<start->children[0]->line<<"\n";
                    error = 1;
                    return code;
                }
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<start->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("STORE "+ std::to_string(iterator.memory));
                }
                else{
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("STORE "+ std::to_string(iterator.memory));
                }
            }
        }
    }

    //w memory +1 przechowujemy wartość for_node->children[1]
    long long end_memory = memory + 1;
    memory++;
    check_memory();
    ASTNode* end = for_node->children[1];

    if(end->type == NODE_NUM){
        code.push_back(std::string("SET ") + end->value);
        code.push_back("STORE "+ std::to_string(end_memory));
    }
    else if(end->type == NODE_VAR){
        variable var = find_var(end->value);
        if(var.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< end->value <<" : linia "<<end->line<<"\n";
            error = 1;
            return code;
        }
        if(var.tab == 1){
            std::cerr<<"błąd: nie podano miejsca w tablicy "<< end->value <<" : linia "<<end->line<<"\n";
            error = 1;
            return code;
        }
        if(var.is_arg == 0){
            if(var.assign == 0){
                std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< end->value <<" : linia "<<end->line<<"\n";
                error = 1;
                return code;
            }
            code.push_back("LOAD "+ std::to_string(var.memory));
            code.push_back("STORE "+ std::to_string(end_memory));
        }
        else{
            code.push_back("LOADI "+ std::to_string(var.memory));
            code.push_back("STORE "+ std::to_string(end_memory));
        }
    }
    else{
        variable tab = find_var(end->value);
        if(tab.name == nullptr){
            std::cerr<<"błąd:  nie znaleziono zmiennej "<< end->value <<" : linia "<<end->line<<"\n";
            error = 1;
            return code;
        }
        if(tab.tab == 0){
            error = true;
            std::cerr<<"błąd: to nie jest tablica - "<< tab.name <<" : linia "<<end->line<<"\n";
            return code;
        }

        if(tab.is_arg == 0){
            if(end->children[0]->type == NODE_NUM){
                if(tab.start_index > std::stoll(std::string(end->children[0]->value)) && tab.end_index < std::stoll(std::string(end->children[0]->value))){
                    error = true;
                    std::cerr<<"błąd: wychodzimy poza tablice "<< tab.name <<" : linia "<<end->children[0]->line<<"\n";
                    return code;
                }
                code.push_back("LOAD "+ std::to_string(tab.memory - tab.start_index +  std::stoll(std::string(end->children[0]->value))));
                code.push_back("STORE "+ std::to_string(end_memory));
            }
            else if(end->children[0]->type == NODE_VAR){
                variable index = find_var(end->children[0]->value);
                if(index.name == nullptr){
                    std::cerr<<"błąd:  nie znaleziono zmiennej "<< end->children[0]->value <<" : linia "<<end->children[0]->line<<"\n";
                    error = 1;
                    return code;
                }
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<end->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("SET "+ std::to_string(tab.memory));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("STORE "+ std::to_string(end_memory));
                }
                else{
                    code.push_back("SET "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("STORE "+ std::to_string(end_memory));
                }
            }
        }
        else{
            if(end->children[0]->type == NODE_NUM){
                code.push_back(std::string("SET ") + end->children[0]->value);
                code.push_back("ADD "+ std::to_string(tab.memory));
                code.push_back("LOADI "+ std::to_string(0));
                code.push_back("STORE "+ std::to_string(end_memory));
            }
            else if(end->children[0]->type == NODE_VAR){
                variable index = find_var(end->children[0]->value);
                if(index.name == nullptr){
                    std::cerr<<"błąd:  nie znaleziono zmiennej "<< end->children[0]->value <<" : linia "<<end->children[0]->line<<"\n";
                    error = 1;
                    return code;
                }
                if(index.is_arg == 0){
                    if(index.assign == 0){
                        std::cerr<<"błąd:  nie przypisano wartości do zmiennej "<< index.name <<" : linia "<<end->children[0]->line<<"\n";
                        error = 1;
                        return code;
                    }
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADD "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("STORE "+ std::to_string(end_memory));
                }
                else{
                    code.push_back("LOAD "+ std::to_string(tab.memory));
                    code.push_back("ADDI "+ std::to_string(index.memory));
                    code.push_back("LOADI "+ std::to_string(0));
                    code.push_back("STORE "+ std::to_string(end_memory));
                }
            }
        }
    }

    ASTNode* for_commands = for_node->children[2];
    std::vector<std::string> for_com = output(for_commands);

    //sprawdzenie warunku
    code.push_back("LOAD "+ std::to_string(end_memory));
    code.push_back("SUB "+ std::to_string(iterator.memory));

    if(is_downto == false){
        code.push_back("JNEG "+ std::to_string(for_com.size()+5));
    }
    else{
        code.push_back("JPOS "+ std::to_string(for_com.size()+5));
    } 

    for(std::string s : for_com){
        code.push_back(s);
    }
    //iterator + 1 / - 1
    if(is_downto == false){
        code.push_back("SET 1");
        code.push_back("ADD "+ std::to_string(iterator.memory));
        code.push_back("STORE "+ std::to_string(iterator.memory));
    }
    else{
        code.push_back("SET -1");
        code.push_back("ADD "+ std::to_string(iterator.memory));
        code.push_back("STORE "+ std::to_string(iterator.memory));
    }

    //wróć na początek for
    code.push_back("JUMP -"+ std::to_string(for_com.size() + 6));

    //usuwamy z pamięci iterator 
    remove_variable(iterator.name);
    if(memory == end_memory){
        memory = memory - 2;
    }
    
    return code;
}

std::vector<std::string> output(ASTNode* node) {
    std::vector<std::string> code;

    if(node->type == NODE_COMMANDS){
        for (ASTNode* child : node->children) {
            std::vector<std::string> com = output(child);
            for(std::string s : com){
                code.push_back(s);
            }
        }
    }

    if(node->type == NODE_CALL){
       code = call(node);
    }

    if(node->type == NODE_READ){
        code = read(node);
    }
    if(node->type == NODE_WRITE){
        code = write(node);
    }
    if(node->type == NODE_ASSIGN){
        code = assign(node);
    }
    if(node->type == NODE_IF){
        code = if_code(node);
    }
    if(node->type == NODE_WHILE){
        code = while_code(node);
    }
    if(node->type == NODE_REPEAT){
        code = repeat(node);
    }
    if(node->type == NODE_FOR){
        code = for_code(node, 0);
    }
    if(node->type == NODE_FORDWONTO){
        code = for_code(node, 1);
    }
    return code;
}

std::vector<std::string> proc_call_jump(std::vector<std::string>code){
    for (size_t i = 0; i < code.size(); ++i) {
        if (code[i] == "SET linika + 4") {
            // Zamiana na "SET X" gdzie X to miejsce gdzie ma skoczyć z powrotem
            code[i] = "SET " + std::to_string(i + 4 + output_code.size()-1);
        }
        else if (code[i].substr(0, 17) == "JUMP - linijka + ") {
            // Wyciąganie liczby z części "JUMP - linijka + X"
            size_t pos = code[i].find_last_of(" +");
            if (pos != std::string::npos) {
                std::string number_str = code[i].substr(pos + 1);
                
                long long line_number = std::stoll(number_str); 
                // Tworzymy nowy "JUMP X" gdzie X to indeks + 4
                code[i] = "JUMP -" + std::to_string(i - line_number + output_code.size());
            }
        }
    }
    return code;
}

void write_code(std::vector<std::string>code ){
    code = proc_call_jump(code);
    for(std::string s : code){
        output_code.push_back(s);
        lines++;
    }
}

void memory_check(){
    for(variable var : variables){
        std::cout<<var.memory<<"\n";
        std::cout<<var.name<<"\n";
    }
}

void pros(ASTNode* procs){
    std::vector<ASTNode*> p;
    while(procs->type == NODE_PROC){
        procs->children.pop_back();
        p.push_back(procs);
        procs = procs->children[1];
    }
    for(long long i = p.size() - 1; i>=0;i--){
        var_proc.push_back(variables);
        proc procedure = find_proc(p[i]->value, p[i]->line);

        licznik_teraz = procedure.licznik;
        variables = var_proc[procedure.licznik];
        //print_ast(p[i]); 
        std::vector<std::string> c = output(p[i]->children[0]);
        write_code(c);
        output_code.push_back("RTRN "+ std::to_string(procedure.memory));
        lines++; 
        // Sprawdzamy, czy na początku jest "JUMP liczba"
        if (!output_code.empty() && output_code[0].substr(0, 4) == "JUMP") {
            output_code[0] = "JUMP " + std::to_string(lines);
        } 
        else {
            // Dodajemy nowy element na początek
            output_code.insert(output_code.begin(), "JUMP " + std::to_string(lines + 1));
            lines++;
        }
        //memory_check();
    }

    return;
}

void main_commands(ASTNode* main){
    //print_ast(main); 
    variables = var_proc[licznik_proc];
    licznik_teraz = licznik_proc;
    //memory_check();
    std::vector<std::string> c = output(main->children[0]);
    write_code(c);
    output_code.push_back("HALT"); 
    lines++;
}

%}

%union {
    long long val;                
    char* id;    
    struct ASTNode* node;
}

%locations
%token <val> NUM
%token <id> PIDENTIFIER

%token PROGRAM IS PBEGIN END PROCEDURE IF THEN ELSE ENDIF WHILE DO ENDWHILE FOR FROM TO DOWNTO ENDFOR
%token REPEAT UNTIL READ WRITE PLUS MINUS MULT DIV MOD EQUAL NOT GREATER LESS
%token LPAREN RPAREN COMMA COLON SEMICOLON LBRACKET RBRACKET T 

%type <node> value expression condition identifier commands command args proc_call procedures main

%type <id> proc_head args_decl declarations 

%start program_all

%right UMINUS 

%%

program_all
    : procedures main {
                        pros($1);
                        main_commands($2);
    }
    ;

procedures
    : procedures PROCEDURE proc_head IS declarations PBEGIN commands END{   
                                                                            ASTNode* p = create_node(NODE_PROC, $3, @3.first_line);
                                                                            add_child(p,$7);
                                                                            add_child(p, $1);
                                                                            var_proc.push_back(variables);
                                                                            variables.clear();
                                                                            $$ = p;
                                                                        }
    | procedures PROCEDURE proc_head IS PBEGIN commands END {
                                                                ASTNode* p = create_node(NODE_PROC, $3, @3.first_line);
                                                                add_child(p,$6);
                                                                add_child(p, $1);
                                                                var_proc.push_back(variables);
                                                                variables.clear();
                                                                $$ = p;
                                                            }
    | {ASTNode* p = create_node(NODE_END, strdup("-1"), 0); $$ = p;}
    ;

main
    : PROGRAM IS declarations PBEGIN commands END {
                                                       ASTNode* main = create_node(NODE_MAIN, strdup("main"), @1.first_line);
                                                       add_child(main, $5);
                                                       var_proc.push_back(variables);
                                                       $$ = main;
                                                    }
    | PROGRAM IS PBEGIN commands END {
                                        ASTNode* main = create_node(NODE_MAIN, strdup("main"), @1.first_line);
                                        add_child(main, $4);
                                        var_proc.push_back(variables);
                                        $$ = main;
                                    }
    ;

commands
    : commands command {
                            if ($1 == nullptr) {
                                $$ = create_node(NODE_COMMANDS, strdup("commands"), @1.first_line);
                            } else {
                                $$ = $1;
                            }
                            if ($2 != nullptr) { 
                                add_child($$, $2);
                            } else {
                                fprintf(stderr, "Błąd: $2 (command) jest null.\n");
                            }
                        }
    | command {
                    $$ = create_node(NODE_COMMANDS, strdup("commands"), @1.first_line);
                    if ($1 != nullptr) {
                        add_child($$, $1);
                    } else {
                        fprintf(stderr, "Błąd: $1 (command) jest null.\n");
                    }
                }
    ;

command
    : identifier COLON EQUAL expression SEMICOLON {
                                                        ASTNode* assign_node = create_node(NODE_ASSIGN, strdup(":="), @2.first_line);
                                                        add_child(assign_node, $1); // Zmienna
                                                        add_child(assign_node, $4); // Wyrażenie
                                                        $$ = assign_node;
                                                    }
    | IF condition THEN commands ELSE commands ENDIF{
                                                        ASTNode* if_node = create_node(NODE_IF, strdup("if"), @1.first_line);
                                                        add_child(if_node, $2); // Warunek
                                                        add_child(if_node, $4); // Blok THEN
                                                        add_child(if_node, $6); // Blok ELSE
                                                        $$ = if_node;
                                                    }
    | IF condition THEN commands ENDIF {
                                            ASTNode* if_node = create_node(NODE_IF, strdup("if"), @1.first_line);
                                            add_child(if_node, $2); // Warunek
                                            add_child(if_node, $4); // Blok THEN
                                            $$ = if_node;
                                        }
    | WHILE condition DO commands ENDWHILE {
                                                ASTNode* node = create_node(NODE_WHILE, strdup("while"), @1.first_line);
                                                add_child(node, $2); // Warunek
                                                add_child(node, $4); // pętla
                                                $$ = node;
                                            }
    | REPEAT commands UNTIL condition SEMICOLON {
                                                    ASTNode* node = create_node(NODE_REPEAT, strdup("repeat"), @1.first_line);
                                                    add_child(node, $2); // petla
                                                    add_child(node, $4); // warunek
                                                    $$ = node;
                                                }
    | FOR PIDENTIFIER FROM value TO value DO commands ENDFOR{
                                                                ASTNode* for_node = create_node(NODE_FOR, strdup($2), @2.first_line);
                                                                add_child(for_node, $4); // początek zakresu
                                                                add_child(for_node, $6); // koniec zakresu
                                                                add_child(for_node, $8); //  instrukcje wewnętrzne
                                                                $$ = for_node; 
                                                            }
    | FOR PIDENTIFIER FROM value DOWNTO value DO commands ENDFOR {
                                                                ASTNode* for_node = create_node(NODE_FORDWONTO, strdup($2), @2.first_line);
                                                                add_child(for_node, $4); // początek zakresu
                                                                add_child(for_node, $6); // koniec zakresu
                                                                add_child(for_node, $8); //  instrukcje wewnętrzne
                                                                $$ = for_node; 
                                                            }
    | proc_call SEMICOLON {$$=$1;}
    | READ identifier SEMICOLON {
                                    ASTNode* node = create_node(NODE_READ, strdup("read"), @1.first_line);
                                    if ($2 != nullptr) {
                                        add_child(node, $2);
                                    } else {
                                        fprintf(stderr, "Błąd: $2 (identifier) jest null.\n");
                                    }
                                    $$ = node;
                                }
    | WRITE value SEMICOLON {
                                    ASTNode* node = create_node(NODE_WRITE, strdup("write"), @1.first_line);
                                    if ($2 != nullptr) {
                                        add_child(node, $2);
                                    } else {
                                        fprintf(stderr, "Błąd: $2 (identifier) jest null.\n");
                                    }
                                    $$ = node;
                                }
    ;

proc_head
    : PIDENTIFIER LPAREN args_decl RPAREN {create_proc($1,  @1.first_line); $$ = $1;}
    ;
proc_call
    : PIDENTIFIER LPAREN args RPAREN{
                                        ASTNode* node = create_node(NODE_CALL, strdup($1), @1.first_line);
                                        if ($3 != nullptr) {
                                            add_child(node, $3);
                                        } else {
                                            fprintf(stderr, "Błąd: $3 (pidentifier) jest null.\n");
                                        }
                                        $$=node;
                                    }
    ;

declarations
    : declarations COMMA PIDENTIFIER {add_var($3, @3.first_line);}
    | declarations COMMA PIDENTIFIER LBRACKET NUM COLON NUM RBRACKET {{add_tab_var($3, $5, $7, @3.first_line);}}
    | declarations COMMA PIDENTIFIER LBRACKET MINUS NUM COLON NUM RBRACKET %prec UMINUS{{add_tab_var($3, -$6, $8, @3.first_line);}}
    | declarations COMMA PIDENTIFIER LBRACKET MINUS NUM COLON MINUS NUM RBRACKET %prec UMINUS{{add_tab_var($3, -$6, -$9, @3.first_line);}}
    | PIDENTIFIER {{add_var($1, @1.first_line);}}
    | PIDENTIFIER LBRACKET NUM COLON NUM RBRACKET {{add_tab_var($1, $3, $5,  @1.first_line);}}
    | PIDENTIFIER LBRACKET MINUS NUM COLON NUM RBRACKET %prec UMINUS {{add_tab_var($1, -$4, $6,  @3.first_line);}}
    | PIDENTIFIER LBRACKET MINUS NUM COLON MINUS NUM RBRACKET %prec UMINUS {{add_tab_var($1, -$4, -$7,  @3.first_line);}}
    | PIDENTIFIER LBRACKET NUM COLON MINUS NUM RBRACKET %prec UMINUS {error = true; std::cerr<< "błąd: ujemna wielkość tablicy w linii "<<@3.first_line<<"\n"; }
    ;

args_decl
    : args_decl COMMA PIDENTIFIER { add_arg($3, @3.first_line);}
    | args_decl COMMA T PIDENTIFIER {add_tab_arg($4, @4.first_line);}
    | PIDENTIFIER { add_arg($1, @1.first_line);}
    | T PIDENTIFIER {add_tab_arg($2, @2.first_line);}
    ;

args
    : args COMMA PIDENTIFIER {
                                if ($1 == nullptr) {
                                    $$ = create_node(NODE_ARG, strdup("arguments"), @3.first_line);
                                } else {
                                    $$ = $1;
                                }
                                if ($3 != nullptr) { 
                                    ASTNode* name = create_node(NODE_VAR, strdup($3), @3.first_line);
                                    add_child($$, name);
                                } else {
                                    fprintf(stderr, "Błąd: $3 (command) jest null.\n");
                                }
                                $$=$1;
                            }
    | PIDENTIFIER {
                    $$ = create_node(NODE_ARG, strdup("arguments"), @1.first_line);
                    ASTNode* name = create_node(NODE_VAR, strdup($1), @1.first_line);
                    add_child($$, name);
                    
                }
    ;

expression
    : value
    | value PLUS value {
                            ASTNode* minus_node = create_node(NODE_ARITHMETIC, strdup("+"), @2.first_line);
                            add_child(minus_node, $1); // Lewe operand
                            add_child(minus_node, $3); // Prawe operand
                            $$ = minus_node;
                        }
    | value MINUS value {
                            ASTNode* minus_node = create_node(NODE_ARITHMETIC, strdup("-"), @2.first_line);
                            add_child(minus_node, $1); // Lewe operand
                            add_child(minus_node, $3); // Prawe operand
                            $$ = minus_node;
                        }
    | value MULT value {
                            ASTNode* minus_node = create_node(NODE_ARITHMETIC, strdup("*"), @2.first_line);
                            add_child(minus_node, $1); // Lewe operand
                            add_child(minus_node, $3); // Prawe operand
                            $$ = minus_node;
                        }
    | value DIV value{
                            ASTNode* minus_node = create_node(NODE_ARITHMETIC, strdup("/"), @2.first_line);
                            add_child(minus_node, $1); // Lewe operand
                            add_child(minus_node, $3); // Prawe operand
                            $$ = minus_node;
                        }
    | value MOD value {
                            ASTNode* minus_node = create_node(NODE_ARITHMETIC, strdup("%"), @2.first_line);
                            add_child(minus_node, $1); // Lewe operand
                            add_child(minus_node, $3); // Prawe operand
                            $$ = minus_node;
                        }
    ;

condition
    : value EQUAL value {
                            ASTNode* equal_node = create_node(NODE_ARITHMETIC, strdup("="), @2.first_line);
                            add_child(equal_node, $1); // Lewe operand
                            add_child(equal_node, $3); // Prawe operand
                            $$ = equal_node;
                        }
    | value NOT EQUAL value {
                            ASTNode* equal_node = create_node(NODE_ARITHMETIC, strdup("!="), @2.first_line);
                            add_child(equal_node, $1); // Lewe operand
                            add_child(equal_node, $4); // Prawe operand
                            $$ = equal_node;
                        }
    | value GREATER value{
                            ASTNode* equal_node = create_node(NODE_ARITHMETIC, strdup(">"), @2.first_line);
                            add_child(equal_node, $1); // Lewe operand
                            add_child(equal_node, $3); // Prawe operand
                            $$ = equal_node;
                        }
    | value LESS value {
                            ASTNode* equal_node = create_node(NODE_ARITHMETIC, strdup("<"), @2.first_line);
                            add_child(equal_node, $1); // Lewe operand
                            add_child(equal_node, $3); // Prawe operand
                            $$ = equal_node;
                        }
    | value GREATER EQUAL value {
                            ASTNode* equal_node = create_node(NODE_ARITHMETIC, strdup(">="), @2.first_line);
                            add_child(equal_node, $1); // Lewe operand
                            add_child(equal_node, $4); // Prawe operand
                            $$ = equal_node;
                        }
    | value LESS EQUAL value {
                            ASTNode* equal_node = create_node(NODE_ARITHMETIC, strdup("<="), @2.first_line);
                            add_child(equal_node, $1); // Lewe operand
                            add_child(equal_node, $4); // Prawe operand
                            $$ = equal_node;
                        }
    ;

value
    : NUM {$$ = create_node(NODE_NUM, strdup(std::to_string($1).c_str()), @1.first_line); }
    | identifier {$$ = $1;}
    | MINUS NUM %prec UMINUS {$$ = create_node(NODE_NUM, strdup(std::to_string(-$2).c_str()), @2.first_line);}
;

identifier
    : PIDENTIFIER {
        $$ = create_node(NODE_VAR, strdup($1), @1.first_line); 
    }
    | PIDENTIFIER LBRACKET NUM RBRACKET {
        ASTNode* array_node = create_node(NODE_TAB, strdup($1), @1.first_line); 
        add_child(array_node, create_node(NODE_NUM, strdup(std::to_string($3).c_str()), @3.first_line)); 
        $$ = array_node;
    }
    | PIDENTIFIER LBRACKET MINUS NUM RBRACKET %prec UMINUS {
        ASTNode* array_node = create_node(NODE_TAB, strdup($1), @1.first_line); 
        add_child(array_node, create_node(NODE_NUM, strdup(std::to_string(-$4).c_str()),@4.first_line)); 
        
        $$ = array_node;
    }
    | PIDENTIFIER LBRACKET PIDENTIFIER RBRACKET {
        ASTNode* array_node = create_node(NODE_TAB, strdup($1), @1.first_line); 
        add_child(array_node, create_node(NODE_VAR, strdup($3), @3.first_line));
        $$ = array_node;
    }
;

%%

void yyerror(const char* msg) {
    std::cerr << "Błąd parsowania w linii " << yylineno << ": " << msg << std::endl;
    exit(1);
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Użycie: " << argv[0] << " <nazwa pliku wejściowego> <nazwa pliku wyjściowego>" << std::endl;
        return 1;
    }

    // Otwieranie pliku wejściowego
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        std::cerr << "Nie można otworzyć pliku wejściowego: " << argv[1] << std::endl;
        return 1;
    }

    // Otwieranie pliku wyjściowego
    yyout = fopen(argv[2], "w");
    if (!yyout) {
        std::cerr << "Nie można otworzyć pliku wyjściowego: " << argv[2] << std::endl;
        fclose(yyin);
        return 1;
    }
    // Parsowanie
    if (yyparse() == 0) {
        if(error == 0){
            for (const auto& lin : output_code) {
                fprintf(yyout, "%s\n", lin.c_str());
            }
        }
    } 

    fclose(yyin);
    fclose(yyout);
    return 0;
}
