# This file contains methods to generate a data set of instances (i.e., sudoku grids)
include("io.jl")

"""
Generate an n*n grid

Argument
- n: size of the grid
"""
function generateInstance(n::Int)::Matrix{Int}
    # Initialisation de la matrice avec des zéros
    instance = zeros(Int, n, n)
    
    # Remplissage de la matrice avec des entiers aléatoires entre 1 et n
    for i in 1:n
        for j in 1:n
            instance[i, j] = rand(1:n)
        end
    end
    
    return instance
end

"""
Generate all the instances

Remark: a grid is generated only if the corresponding output file does not already exist
"""

function generateDataSet(nb_of_instances::Int, max_size::Int)
    for i in 1:nb_of_instances
        # Génère une taille aléatoire pour la matrice entre 2 et max_size
        size = rand(2:max_size)
        G = generateInstance(size)
        filename = "size$(size)no$(i).txt"

        open("./data/$filename", "w") do io
            for j in 1:size
                join(io, G[j,:], ",")
                j < size && println(io)
            end
        end
    end
end

