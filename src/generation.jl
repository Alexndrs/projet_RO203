# This file contains methods to generate a data set of instances (i.e., sudoku grids)
include("io.jl")

"""
Generate an n*n grid

Argument
- n: size of the grid
"""

function isNotPossible(X, i, j)
    n = size(X, 1)  # Taille de la matrice

    # Vérifie si au moins une des coordonnées adjacentes vaut 1
    if i > 1 && X[i-1, j] == 1
        return true
    end
    if i < n && X[i+1, j] == 1
        return true
    end
    if j > 1 && X[i, j-1] == 1
        return true
    end
    if j < n && X[i, j+1] == 1
        return true
    end

    # Si aucune coordonnée adjacente ne vaut 1, renvoie false
    return false
end

function isNotCompatible(g,G,X,i,j)
    if i==1 && j==1
        return false
    end
    if j>1
        for j1 in 1:(j-1)
            if G[i, j1] == g
                return true
            end
        end
    end
    if i>1
        for i1 in 1:(i-1)
            if G[i1, j] == g
                return true
            end
        end
    end
    return false
end


function generateInstance(n::Int)::Tuple{Bool, Matrix{Int64}}
    # Initialisation de la matrice avec des zéros
    G = zeros(Int, n, n)
    

    # Remplissage de la matrice avec des entiers aléatoires entre 1 et n
    X = zeros(n,n)
    nb_case_noir_par_ligne = div(n, 6)
    for i in 1:n
        j = rand(1:n)
        k_try = 1000
        k = 0
        while isNotPossible(X,i,j) && k < k_try
            j = rand(1:n)
            k += 1
        end
        if k != k_try
            X[i,j] = 1
        end
    end



    for i in 1:n
        for j in 1:n
            if X[i,j] == 0
                #On doit générer un nombre aléatoire compatible avec les nombres déjà écris sur cette ligne et colone
                g = rand(1:n)
                k_try = 1000
                k = 0
                while isNotCompatible(g,G,X,i,j) && k < k_try
                    g = rand(1:n)
                    k += 1
                end
                if k != k_try
                    G[i,j] = g
                else
                    # La répartition des cases noir ne permet pas d'avoir une possibilité compatible sur la case (i,j) avec les cases precedentes
                    G[i,j] = -1
                    return false,G
                end
            else
                # Cette case devra être noirci dont ça ne nous importe pas qu'elle soit compatible
                G[i, j] = rand(1:n)
            end
        end
    end
    
    println(G)
    return true, G
end

"""
Generate all the instances

Remark: a grid is generated only if the corresponding output file does not already exist
"""

function generateDataSet(nb_of_instances::Int, max_size::Int)
    for i in 1:nb_of_instances
        # Génère une taille aléatoire pour la matrice entre 2 et max_size
        size = rand(2:max_size)
        isCorrect, G = generateInstance(size)
        while !isCorrect
            isCorrect, G = generateInstance(size)
        end
        filename = "size$(size)no$(i).txt"

        open("../data/$filename", "w") do io
            for j in 1:size
                join(io, G[j,:], ",")
                j < size && println(io)
            end
        end
    end
end

