A = rand(3, 3)
B = ones(4, 4)
C = randn(5, 6)
K = A ⊗ B
X = collect(K)
v = rand(12)

K3 = A ⊗ B ⊗ C

@testset "multiply" begin
    @testset "Compatibility with other matrix ops" begin
        K = rand(3, 3) ⊗ randn(4, 4)
        K3 = rand(3, 3) ⊗ randn(4, 4) ⊗ randn(5, 6)
        KPow = kronecker(randn(3, 3), 3)

        for op in [adjoint, transpose, inv, pinv, conj]
            @test collect(op(K)) ≈ op(collect(K))
            if op != inv
                @test collect(op(K3)) ≈ op(collect(K3))
            else
                @test_throws DimensionMismatch op(K3)
            end
        end
    end

    @testset "Compatibility with Matrix Product" begin
        A_f = [randn(3, 4), randn(5, 6)]
        B_f = [randn(4, 2), randn(6, 7)]

        A = kronecker(A_f...)
        B = kronecker(B_f...)

        @test collect(A * B) ≈ collect(kronecker(map(*, A_f, B_f)...))

        C = randn(3, 3)
        D = randn(3, 2)
        C_pow = kronecker(C, 3)
        D_pow = kronecker(D, 3)
        @test collect(C_pow * D_pow) ≈ collect(kronecker(C*D, 3))

        @test_throws DimensionMismatch (D_pow * C_pow)
    end

    @testset "Vec trick" begin

        @test K * v ≈ X * v

        V = rand(4, 3)
        @test K * vec(V) ≈ X * vec(V)
        @test_throws DimensionMismatch K * V
        @test_throws DimensionMismatch K * reshape(V, 2, 6)

        v3 = randn(size(K3, 2))
        @test K3 * v3 ≈ collect(K3) * v3
        u = similar(v)
        @test mul!(u, K, v) ≈ X * v
    end

    @testset "Reshaped vec trick" begin
        @test K * v ≈ X * v

        V = sprand(4, 3, 1.0)
        @test K * vec(V) ≈ X * vec(V)
        @test_throws DimensionMismatch K * V
        @test_throws DimensionMismatch K * reshape(V, 2, 6)
        K3 = A ⊗ B ⊗ C
        v3 = sprand(size(K3, 2),1.0)
        @test K3 * vec(v3) ≈ collect(K3) * v3
        u = similar(v)
        @test mul!(u, K, v) ≈ X * v

    end

    @testset "AbstractKroneckerProduct * AbstractMatrix" begin
        rng = MersenneTwister(123456)
        a, b, x = randn(rng, 30, 20), randn(rng, 40, 50), randn(rng, 1000, 1100)

        @test kron(a, b) * x ≈ (a ⊗ b) * x
        @test kron(a, Eye(50)) * x ≈ (a ⊗ Eye(50)) * x
        @test kron(Eye(20), b) * x ≈ (Eye(20) ⊗ b) * x
    end

    @testset "sum" begin
        @test sum(K) ≈ sum(X)
        @test sum(K3) ≈ sum(collect(K3))

        @test sum(K, dims=1) ≈ sum(X, dims=1)
        @test sum(K3, dims=2) ≈ sum(collect(K3), dims=2)
        @test sum(K3, dims=2) isa AbstractKroneckerProduct

        @test sum(kronecker(A, 3)) ≈ sum(kron(A, A, A))
    end

    @inline function compare_against_kron(K, k, x, X, y, Y)
        @test collect(K) ≈ k

        res1 = (K * x)
        res2 = (K * X)
        @test res1 ≈ (k * x)
        @test res2 ≈ (k * X)

        if K isa AbstractKroneckerProduct
            res3 = (K \ y)
            res4 = (K \ Y)
            @test res3 ≈ (k \ y)
            @test res4 ≈ (k \ Y)
        end

        if size(K, 1) == size(x, 1)
            res1a = (x' * K)
            res1t = (transpose(x) * K)

            @test res1a ≈ (x' * k)
            @test res1t ≈ (transpose(x) * k)
            @test (K' * x) ≈ (k' * x) ≈ res1a'
            @test (transpose(K) * x) ≈ (transpose(k) * x) ≈ transpose(res1t)
        else
            @test_throws DimensionMismatch (x' * K)
            @test_throws DimensionMismatch (transpose(x) * K)
        end

        if size(K, 1) == size(X, 1)
            res2a = (X' * K)
            res2t = (transpose(X) * K)

            @test res2a ≈ (X' * k)
            @test res2t ≈ (transpose(X) * k)
            @test (K' * X) ≈ (k' * X) ≈ res2a'
            @test (transpose(K) * X) ≈ (transpose(k) * X) ≈ transpose(res2t)
        else
            @test_throws DimensionMismatch (X' * K)
            @test_throws DimensionMismatch (transpose(X) * K)
        end

    end

    @testset "2-factor square KroneckerProduct" begin
        A = randn(10, 10)
        B = randn(7, 7)
        x = randn(size(A, 2) * size(B, 2))
        X = randn(size(A, 2) * size(B, 2), 4)
        y = randn(size(A, 1) * size(B, 1))
        Y = randn(size(A, 1) * size(B, 1), 4)

        K1 = kronecker(A, B)
        K2 = kronecker(B, A)
        KS = kroneckersum(A, B)

        k1 = kron(A, B)
        k2 = kron(B, A)
        ks = kron(A, Diagonal(I, size(B, 1))) + kron(Diagonal(I, size(A, 1)), B)

        for (K, k) in [(K1, k1), (K2, k2), (KS, ks)]
            compare_against_kron(K, k, x, X, y, Y)
        end
    end


    @testset "2-factor rectangular KroneckerProduct" begin
        A = randn(10, 8)
        B = randn(7, 9)
        x = randn(size(A, 2) * size(B, 2))
        X = randn(size(A, 2) * size(B, 2), 4)
        y = randn(size(A, 1) * size(B, 1))
        Y = randn(size(A, 1) * size(B, 1), 4)

        K1 = kronecker(A, B)
        K2 = kronecker(B, A)
        k1 = kron(A, B)
        k2 = kron(B, A)

        for (K, k) in [(K1, k1), (K2, k2)]
            compare_against_kron(K, k, x, X, y, Y)
        end
    end


    @testset "3-factor rectangular KroneckerProduct" begin
        A = randn(10, 8)
        B = randn(7, 9)
        C = randn(6, 4)
        x = randn(size(A, 2) * size(B, 2) * size(C, 2))
        X = randn(size(A, 2) * size(B, 2) * size(C, 2), 4)
        y = randn(size(A, 1) * size(B, 1) * size(C, 1))
        Y = randn(size(A, 1) * size(B, 1) * size(C, 1), 4)

        K1 = kronecker(A, B, C)
        K2 = kronecker(B, A, C)
        k1 = kron(A, B, C)
        k2 = kron(B, A, C)

        for (K, k) in [(K1, k1), (K2, k2)]
            compare_against_kron(K, k, x, X, y, Y)
        end
    end


    @testset "10-factor square KroneckerProduct" begin
        matrices = [randn(2,2) for i in 1:10]
        v = randn(2^10)
        V = randn(2^10, 5)

        KP = kronecker(matrices...)
        KS = kroneckersum(matrices...)
        kp = kron(matrices...)
        ks = collect(KS)

        for (K, k) in [(KP, kp), (KS, ks)]
            compare_against_kron(K, k, v, V, v, V)
        end
    end

    @testset "10-factor square KroneckerPower" begin
        # reduce condition number of the matrix to avoid accidentally triggering a
        #  test failure
        A = randn(2,2) + 20I
        A /= opnorm(A)

        v = randn(2^10)
        V = randn(2^10, 5)

        K = kronecker(ntuple(_ -> A, 10)...)
        k = kron(ntuple(_ -> A, 10)...)

        compare_against_kron(K, k, v, V, v, V)
    end

    @testset "10-factor rectangular KroneckerProduct" begin
        matrices = [randn(3,2) for i in 1:10]
        x = randn(2^10)
        X = randn(2^10, 5)
        y = randn(3^10)
        Y = randn(3^10, 5)

        K = kronecker(matrices...)
        k = kron(matrices...)

        compare_against_kron(K, k, x, X, y, Y)
    end

    @testset "10-factor mixed KroneckerProduct" begin
        matrices1 = [randn(2,2) for i in 1:5]
        matrices2 = [randn(3,2) for i in 1:5]
        x = randn(2^10)
        X = randn(2^10, 5)
        y = randn(2^5 * 3^5)
        Y = randn(2^5 * 3^5, 5)

        K = kronecker(matrices1..., matrices2...)
        k = kron(matrices1..., matrices2...)

        @test collect(K) ≈ k

        compare_against_kron(K, k, x, X, y, Y)
    end

end
