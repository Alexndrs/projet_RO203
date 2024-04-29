# This file contains methods to solve an instance (heuristically or with CPLEX)
using CPLEX

include("generation.jl")
include("io.jl")

TOL = 0.00001

"""
Solve an instance with CPLEX
"""
function cplexSolve(G::Matrix{Int})

    # Create the model
    m = Model(CPLEX.Optimizer)

    # Start a chronometer
    start = time()

    # Taille de la grille
    n = size(G, 1)

    @variable(m, X[1:n,1:n] >= 0, Bin)

    #Contraintes de non répétition sur chaque colone
    for j in 1:n
        for i1 in 1:n-1
            for i2 in i1+1:n
                if G[i1, j] == G[i2, j]
                    @constraint(m, X[i1, j] + X[i2, j] >= 1)
                end
            end
        end
    end
    
    #Contraintes de non répétition sur chaque ligne
    for i in 1:n
        for j1 in 1:n-1
            for j2 in j1+1:n
                if G[i, j1] == G[i, j2]
                    @constraint(m, X[i, j1] + X[i, j2] >= 1)
                end
            end
        end
    end
    
    #Contraintes de non adjacence vertical des cases noires
    for i in 1:n-1
        for j in 1:n
            @constraint(m, X[i, j] + X[i+1, j] <= 1)
        end
    end

    #Contraintes de non adjacence horizontal des cases noires
    for i in 1:n
        for j in 1:n-1
            @constraint(m, X[i, j] + X[i, j+1] <= 1)
        end
    end
    
    # Objective avoir le nombre minimal de cases noir -> dans l'espérance que
    # ça augmente les chances d'avoir un ensemble de cases blanches restantes qui est connexe
    @objective(m, Min, sum(X[i,j] for i in 1:n, j in 1:n))


    optimize!(m)

    # Vérifie si le solveur a trouvé une solution
    if JuMP.primal_status(m) == MOI.FEASIBLE_POINT
        # Renvoie la valeur des variables et le temps de résolution
        return true, time() - start, value.(X)
    else
        # Renvoie false et le temps de résolution
        return false, time() - start, nothing
    end 
end


"""
Heuristically solve an instance
"""

function getNeighbor(i, j, n)
    voisins = []

    # Voisin en haut
    if i > 1
        push!(voisins, (i-1, j))
    end

    # Voisin en bas
    if i < n
        push!(voisins, (i+1, j))
    end

    # Voisin à gauche
    if j > 1
        push!(voisins, (i, j-1))
    end

    # Voisin à droite
    if j < n
        push!(voisins, (i, j+1))
    end

    return voisins
end


function treatBlackCells(G,X,X_w, blackStack, whiteStack, n)
    # TODO : 
    # -depiler un cellule noir
    # -colorié en blancs les cellules adjacentes et les ajouter à whiteStack
    i,j = pop!(blackStack)
    voisins = getNeighbor(i,j, n)

    for vois in voisins
        push!(whiteStack, vois)
        iv, jv = vois
        X[iv, jv] = 0 # -pas d'intérêt car X est initialisé à 0 mais c'est pour la consistence du code
        X_w[iv,jv] = -1
    end
    return blackStack, whiteStack, X, X_w
end

function treatWhiteCells(G,X,blackStack,whiteStack, n)
    # TODO : 
    # -depiler une cellule blanche
    # -colorié en noir les cellules sur sa ligne et colonne de même valeur et les ajouter à whiteStack
    i,j = pop!(whiteStack)
    for i1 in 1:n
        if i1 != i && G[i1, j] == G[i,j]
            if X[i1, j] != 1
                push!(blackStack, (i1,j))
                X[i1, j] = 1
            end
        end
    end

    for j1 in 1:n
        if j1 != j && G[i, j1] == G[i,j]
            if X[i,j1] != 1
                push!(blackStack, (i,j1))
                X[i, j1] = 1
            end
        end
    end
    return blackStack, whiteStack, X
end

function searchFirstPatern(G,X,n)
    # We search for a patern like 1,2,1
    # In wich we are sure that the 2 should be white because if
    # it was black then we are sure it would be next to one black cell which is not allowed

    for i in 2:(n-1)
        for j in 2:(n-1)
            if (G[i-1,j] == G[i+1,j]) || (G[i,j-1] == G[i,j+1])
                return i,j,true
            end
        end
    end
    return -1,-1,false
end

function searchSecondPatern(G,X,n)
    # We search for a patern like 1,...,1,1,..
    # In wich we are sure that the lonely 1 should be black else if it was white
    # the other 1 who are next to each other should be black, it causes 2 adjacent black cells which is not allowed
    for i in 1:(n-2)
        for j in 1:n
            g = G[i,j]
            for i1 in (i+1):(n-1)
                if G[i1,j] == g && G[i1+1,j] == g
                    return i,j,true
                end
            end
        end
    end
    for i in 1:n
        for j in 1:(n-2)
            g = G[i,j]
            for j1 in (j+1):(n-1)
                if G[i,j1] == g && G[i,j1+1] == g
                    return i,j,true
                end
            end
        end
    end
    return -1,-1,false
end

function getNumberOfRepetion(i,j,G,n)
    res = 0
    g = G[i,j]
    for i1 in 1:n
        if i1 != i && G[i1,j] == g
            res += 1
        end
    end
    for j1 in 1:n
        if j1 != j && G[i,j1] == g
            res += 1
        end
    end
    return res
end

function isNotAllowedSetBlack(i,j,X,n)
    if i<n && X[i+1,j] == 1
        return true
    end
    if i>1 && X[i-1,j] == 1
        return true
    end
    if j<n && X[i,j+1] == 1
        return true
    end
    if j>1 && X[i,j-1] == 1
        return true
    end
    return false
end

function searchDefaultStartPoint(G,X,n)
    # On va simplement prendre la case avec le plus de repetion sur ces lignes et colones et la mettre en noir
    bestCell = (-1,-1)
    maxNbOfRepetion = 0
    for i in 1:n
        for j in 1:n
            nbRep = getNumberOfRepetion(i,j,G,n)
            if nbRep > maxNbOfRepetion && X[i,j] != 1 && !isNotAllowedSetBlack(i,j,X,n)
                maxNbOfRepetion = nbRep
                bestCell = (i,j)
            end
        end
    end
    if bestCell == (-1,-1)
        return 1,1
    end
    return bestCell
end

function findNewCells(G,X,X_w, blackStack, whiteStack, n)

    i,j, firstPaternIsPresent = searchFirstPatern(G,X,n)
    if firstPaternIsPresent && X_w[i,j] != -1
        push!(whiteStack, (i, j))
        X_w[i,j] = -1
        return blackStack, whiteStack, X
    end

    i,j, secondPaternIsPresent = searchSecondPatern(G,X,n)
    if secondPaternIsPresent && X[i,j] != 1
        push!(blackStack, (i, j))
        X[i,j] = 1
        return blackStack, whiteStack, X
    end

    i,j = searchDefaultStartPoint(G,X,n)
    push!(blackStack, (i, j))
    X[i,j] = 1
    return blackStack, whiteStack, X, X_w
end

function isNotSolution(G,X,n)
    for j in 1:n
        for i1 in 1:n
            for i2 in 1:n
                if (i1 != i2) && (G[i1, j] == G[i2,j]) && (X[i1, j]+X[i2, j] == 0 )
                    println(i1,j,i2,j)
                    return true
                end
            end
        end
    end
    for i in 1:n
        for j1 in 1:n
            for j2 in 1:n
                if (j1 != j2) && (G[i, j1] == G[i,j2]) && (X[i, j1]+X[i, j2] == 0 )
                    println(i,j1,i,j2)
                    return true
                end
            end
        end
    end
    for i in 1:(n-1)
        for j in 1:(n-1)
            if (X[i, j] + X[i+1, j] > 1) || (X[i, j] + X[i, j+1] > 1)
                println(i,j)
                return true
            end
        end
    end
    return false
end

function heuristicSolve(G::Matrix{Int})

    n = size(G, 1)
    X = zeros(n,n)
    X_w = zeros(n,n) # ce tableau est un artefact de calcule qui permettra d'indiquer les cases blanches déjà traités en les mettant à -1 dans X_w
    nb_try = 8
    k = 0


    blackStack = []
    whiteStack = []

    while isNotSolution(G, X, n) && k < nb_try
        println(k)
        displaySolution(G,X)
        k += 1

        treatementHasBeenDone = false

        while !isempty(blackStack)
            blackStack, whiteStack, X, X_w = treatBlackCells(G,X,X_w, blackStack, whiteStack, n)
            treatementHasBeenDone = true
            println(whiteStack)
            println(blackStack)
        end
            
        while !isempty(whiteStack)
            blackStack, whiteStack, X = treatWhiteCells(G,X, blackStack, whiteStack, n)
            treatementHasBeenDone = true
            println(whiteStack)
            println(blackStack)
        end

        if !treatementHasBeenDone
            blackStack, whiteStack, X, X_w = findNewCells(G,X,X_w, blackStack, whiteStack, n)
            println(whiteStack)
            println(blackStack)
        end
    end
    return k, X
end 

"""
Solve all the instances contained in "../data" through CPLEX and heuristics

The results are written in "../res/cplex" and "../res/heuristic"

Remark: If an instance has previously been solved (either by cplex or the heuristic) it will not be solved again
"""
function solveDataSet()

    dataFolder = "../data/"
    resFolder = "../res/"

    # Array which contains the name of the resolution methods
    resolutionMethod = ["cplex"]
    #resolutionMethod = ["cplex", "heuristique"]

    # Array which contains the result folder of each resolution method
    resolutionFolder = resFolder .* resolutionMethod

    # Create each result folder if it does not exist
    for folder in resolutionFolder
        if !isdir(folder)
            mkdir(folder)
        end
    end
            
    global isOptimal = false
    global solveTime = -1

    # For each instance
    # (for each file in folder dataFolder which ends by ".txt")
    for file in filter(x->occursin(".txt", x), readdir(dataFolder))  
        
        println("-- Resolution of ", file)
        G = readInputFile(dataFolder * file)

        
        # For each resolution method
        for methodId in 1:size(resolutionMethod, 1)
            
            outputFile = resolutionFolder[methodId] * "/" * file

            # If the instance has not already been solved by this method
            if !isfile(outputFile)
                
                fout = open(outputFile, "w")  

                resolutionTime = -1
                isOptimal = false
                
                # If the method is cplex
                if resolutionMethod[methodId] == "cplex"
                    
                    # Solve it and get the results
                    isOptimal, resolutionTime, res = cplexSolve(G)
                    
                    # If a solution is found, write it
                    if isOptimal
                        println(fout, "res =", res)  
                    end

                # If the method is one of the heuristics
                else
                    
                    isSolved = false

                    # Start a chronometer 
                    startingTime = time()
                    
                    # While the grid is not solved and less than 100 seconds are elapsed
                    while !isOptimal && resolutionTime < 100
                        
                        # TODO 
                        println("In file resolution.jl, in method solveDataSet(), TODO: fix heuristicSolve() arguments and returned values")
                        
                        # Solve it and get the results
                        isOptimal, resolutionTime = heuristicSolve()

                        # Stop the chronometer
                        resolutionTime = time() - startingTime
                        
                    end

                    # Write the solution (if any)
                    if isOptimal

                        # TODO
                        println("In file resolution.jl, in method solveDataSet(), TODO: write the heuristic solution in fout")
                        
                    end 
                end

                println(fout, "solveTime = ", resolutionTime) 
                println(fout, "isOptimal = ", isOptimal)
                
                # TODO
                println("In file resolution.jl, in method solveDataSet(), TODO: write the solution in fout") 
                close(fout)
            end


            # Display the results obtained with the method on the current instance
            #include(outputFile)
            println(resolutionMethod[methodId], " optimal: ", isOptimal)
            println(resolutionMethod[methodId], " time: " * string(round(solveTime, sigdigits=2)) * "s\n")
        end         
    end 
end
