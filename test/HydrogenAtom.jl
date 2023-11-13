using Antiq
using Test
using Printf
using Markdown
using QuadGK
using Symbolics
using Latexify
using LaTeXStrings
HA = antiq(:HydrogenAtom, Z=1, Eₕ=1.0, a₀=1.0, mₑ=1.0, ℏ=1.0)
MP = antiq(:MorsePotential)

# Pₙᵐ(x) = √(1-x²)ᵐ dᵐ/dxᵐ Pₙ(x); Pₙ(x) = 1/(2ⁿn!) dⁿ/dxⁿ (x²-1)ⁿ


println(raw"""
#### Associated Legendre Polynomials $P_n^m(x)$

```math
  \begin{aligned}
    P_n^m(x)
    &= \left( 1-x^2 \right)^{m/2} \frac{\mathrm{d}^m}{\mathrm{d}x^m} P_n(x) \\
    &= \left( 1-x^2 \right)^{m/2} \frac{\mathrm{d}^m}{\mathrm{d}x^m} \frac{1}{2^n n!} \frac{\mathrm{d}^n}{\mathrm{d}x ^n} \left[ \left( x^2-1 \right)^n \right] \\
    &= \frac{1}{2^n} (1-x^2)^{m/2} \sum_{j=0}^{\left\lfloor\frac{n-m}{2}\right\rfloor} (-1)^j \frac{(2n-2j)!}{j! (n-j)! (n-2j-m)!} x^{(n-2j-m)}.
  \end{aligned}
```
""")

@testset "Pₙᵐ(x) = √(1-x²)ᵐ dᵐ/dxᵐ Pₙ(x); Pₙ(x) = 1/(2ⁿn!) dⁿ/dxⁿ (x²-1)ⁿ" begin
  for n in 0:4
  for m in 0:n
      # Rodrigues' formula
      @variables x
      Dn = n==0 ? x->x : Differential(x)^n # dⁿ/dxⁿ
      Dm = m==0 ? x->x : Differential(x)^m # dᵐ/dxᵐ
      a = 1 // (2^n * factorial(n))        # left
      b = (x^2 - 1)^n                      # right
      c = (1 - x^2)^(m//2) * Dm(a * Dn(b)) # Rodrigues' formula
      d = expand_derivatives(c)            # expand dⁿ/dxⁿ and dᵐ/dxᵐ
      e = simplify(d, expand=true)         # simplify
      # closed-form
      eq1 = latexify(e, env=:raw)
      eq2 = latexify(simplify(HA.P(x, n=n, m=m), expand=true), env=:raw)
      # judge
      acceptance = eq1 == eq2
      println("``n=$n, m=$m:`` ", acceptance ? "✔" : "✗")
      @test acceptance
      # show LaTeX
      println("""```math
      \\begin{aligned}
        P_{$n}^{$m}(x)
          = $(latexify(c, env=:raw))
        &= $(eq1) \\\\
        &= $(eq2)
      \\end{aligned}
      ```
      """)
  end
  end
  println("```")
end

println("""```
""")


# ∫Pᵢᵐ(x)Pⱼᵐ(x)dx = 2(j+m)!/(2j+1)(j-m)! δᵢⱼ


println(raw"""
#### Normalization & Orthogonality of $P_n^m(x)$

```math
\int_{-1}^{1} P_i^m(x) P_j^m(x) \mathrm{d}x = \frac{2(j+m)!}{(2j+1)(j-m)!} \delta_{ij}
```
```""")

@testset "∫Pᵢᵐ(x)Pⱼᵐ(x)dx = 2(j+m)!/(2j+1)(j-m)! δᵢⱼ" begin
  println("  m\t  i\t  j\tnumerical         \tanalytical        \t|error|")
  for m in 0:5
  for i in m:9
  for j in m:9
    numerical  = quadgk(x -> HA.P(x, n=i, m=m) * HA.P(x, n=j, m=m), -1, 1, maxevals=10^3)[1]
    analytical = 2*factorial(j+m)/(2*j+1)/factorial(j-m)*(i == j ? 1 : 0)
    error = analytical == 0 ? (abs(numerical) < 1e-5 ? 0.0 : Inf) : abs((numerical-analytical)/analytical)
    acceptance = error < 1e-5
    @test acceptance
    @printf("%3d\t%3d\t%3d\t%.16f\t%.16f\t%.16f%%\t%s\n", m, i, j, numerical, analytical, error*100, acceptance ? "✔" :  "✗")
  end
  end
  end
end

println("""```
""")


# ∫Yₗ₁ₘ₁(θ,φ)Yₗ₂ₘ₂(θ,φ)sinθdθdφ = δₗ₁ₗ₂δₘ₁ₘ₂


println(raw"""
#### Normalization & Orthogonality of $Y_{lm}(\theta,\varphi)$

```math
\int_0^{2\pi}
\int_0^\pi
Y_{lm}(\theta,\varphi)^* Y_{l'm'}(\theta,\varphi) \sin(\theta)
~\mathrm{d}\theta \mathrm{d}\varphi
= \delta_{ll'} \delta_{mm'}
```
```""")

@testset "∫Yₗ₁ₘ₁(θ,φ)Yₗ₂ₘ₂(θ,φ)sinθdθdφ = δₗ₁ₗ₂δₘ₁ₘ₂" begin
  println(" l1 l2 m1 m2\tnumerical\t        analyrical        \t|error|")
  for l1 in 0:2
  for l2 in 0:2
  for m1 in -l1:l1
  for m2 in -l2:l2
    numerical = (
      quadgk(φ ->
      quadgk(θ ->
        conj(HA.Y(θ,φ,l=l1,m=m1)) * HA.Y(θ,φ,l=l2,m=m2) * sin(θ)
      , 0, π, maxevals=50)[1]
      , 0, 2π, maxevals=100)[1]
    )
    analytical = (l1 == l2 ? 1 : 0) * (m1 == m2 ? 1 : 0)
    error = analytical == 0 ? (abs(numerical) < 1e-5 ? 0.0 : Inf) : abs((numerical-analytical)/analytical)
    acceptance = error <1e-5
    @test acceptance
    @printf("%3d%3d%3d%3d\t%.16f\t%.16f\t%.16f%%\t%s\n", l1, l2, m1, m2, real(numerical), analytical, error*100, acceptance ? "✔" :  "✗")
  end
  end
  end
  end
end

println("""```
""")


# Lₙᵏ(x) = dᵏ/dxᵏ Lₙ(x); Lₙ(x) = 1/(n!) eˣ dⁿ/dxⁿ e⁻ˣ xⁿ


println(raw"""
#### Associated Laguerre Polynomials $L_n^{k}(x)$

```math
  \begin{aligned}
  L_n^{k}(x)
    &= \frac{\mathrm{d}^k}{\mathrm{d}x^k} L_n(x) \\
    &= \frac{\mathrm{d}^k}{\mathrm{d}x^k} \frac{1}{n!} \mathrm{e}^x \frac{\mathrm{d}^n}{\mathrm{d}x ^n} \left( \mathrm{e}^{-x} x^n \right) \\
    &= \sum_{m=0}^{n-k} (-1)^{m+k} \frac{n!}{m!(m+k)!(n-m-k)!} x^m \\
    &= (-1)^k L_{n-k}^{(k)}(x)
  \end{aligned}
```
""")

@testset "Lₙᵏ(x) = dᵏ/dxᵏ Lₙ(x); Lₙ(x) = 1/(n!) eˣ dⁿ/dxⁿ e⁻ˣ xⁿ" begin
  for n in 0:4
  for k in 0:n
    # Rodriguesの公式の展開
    @variables x
    Dn = n==0 ? x->x : Differential(x)^n # dⁿ/dxⁿ
    Dk = k==0 ? x->x : Differential(x)^k # dᵐ/dxᵐ
    a = exp(x) / factorial(n)            # left
    b = exp(-x) * x^n                    # right
    c = Dk(a * Dn(b))                    # Rodrigues' formula
    d = expand_derivatives(c)            # expand dⁿ/dxⁿ and dᵐ/dxᵐ
    e = simplify(d, expand=true)         # simplify
    # closed-form
    eq1 = latexify(e, env=:raw)
    eq2 = latexify(HA.L(x, n=n, k=k), env=:raw)
    eq3 = latexify((-1)^k * MP.Lαint(x, n=n-k, α=k), env=:raw)
    # judge
    acceptance = (eq1 == eq2) && (eq1 == eq3)
    println("``n=$n, k=$k:`` ", acceptance ? "✔" : "✗")
    @test acceptance
    # show LaTeX
    println("""```math
    \\begin{aligned}
      L_{$n}^{$k}(x)
       = $(latexify(c, env=:raw))
      &= $(eq1) \\\\
      &= $(eq2) \\\\
      &= $(eq3)
    \\end{aligned}
    ```
    """)
  end
  end
  println("```")
end

println("""```
""")


# ∫exp(-x)xᵏLᵢᵏ(x)Lⱼᵏ(x)dx = (2i+k)!/(i+k)! δᵢⱼ


println(raw"""
#### Normalization & Orthogonality of $L_n^{k}(x)$

```math
\int_{0}^{\infty} \mathrm{e}^{-x} x^k L_i^k(x) L_j^k(x) \mathrm{d}x = \frac{i!}{(i-k)!} \delta_{ij}
```

Replace $n+k$ with $n$ for [the definition of Wolfram MathWorld](https://mathworld.wolfram.com/AssociatedLaguerrePolynomial.html).
```""")

@testset "∫exp(-x)xᵏLᵢᵏ(x)Lⱼᵏ(x)dx = (2i+k)!/(i+k)! δᵢⱼ" begin
  println("  i\t  j\t  k\tnumerical         \tanalytical        \t|error|")
  for i in 0:7
  for j in 0:7
  for k in 0:min(i,j)
    numerical  = quadgk(x -> exp(-x) * x^k * HA.L(x, n=i, k=k) * HA.L(x, n=j, k=k), 0, Inf, maxevals=10^3)[1]
    analytical = factorial(i) / factorial(i-k) * (i == j ? 1 : 0)
    error = analytical == 0 ? (abs(numerical) < 1e-5 ? 0.0 : Inf) : abs((numerical-analytical)/analytical)
    acceptance = error < 1e-5
    @test acceptance
    @printf("%3d\t%3d\t%3d\t%.16f\t%.16f\t%.16f%%\t%s\n", i, j, k, numerical, analytical, error*100, acceptance ? "✔" :  "✗")
  end
  end
  end
end

println("""```
""")


# ∫|Rₙₗ(r)|²r²dr = δₙ₁ₙ₂δₗ₁ₗ₂


println(raw"""
#### Normalization of $R_{nl}(r)$

```math
\int |R_{nl}(r)|^2 r^2 \mathrm{d}r = 1
```
```""")

@testset "∫|Rₙₗ(r)|²r²dr = δₙ₁ₙ₂δₗ₁ₗ₂" begin
  println("  n\t  l\tnumerical         \tanalytical        \t|error|")
  for n in 1:9
  for l in 0:n-1
    numerical  = quadgk(r -> r^2 * HA.R(r,n=n,l=l)^2, 0, Inf, maxevals=10^3)[1]
    analytical = 1 # (n1 == n2 ? 1 : 0) * (l1 == l2 ? 1 : 0)
    error = analytical == 0 ? (abs(numerical) < 1e-5 ? 0.0 : Inf) : abs((numerical-analytical)/analytical)
    acceptance = error < 1e-5
    @test acceptance
    @printf("%3d\t%3d\t%.16f\t%.16f\t%.16f%%\t%s\n", n, l, numerical, analytical, error*100, acceptance ? "✔" :  "✗")
  end
  end
end

println("""```
""")


# ∫r|Rₙₗ(r)|²r²dr = (a₀×mₑ/μ)/2Z × [3n²-l(l+1)]; 1/μ = 1/mₑ + 1/mₚ


println(raw"""
#### Expected Value of $r$

```math
\langle r \rangle
= \int r |R_{n_1 l_1}(r)|^2 r^2 \mathrm{d}r
= \frac{a_\mu}{2Z} \left[ 3n^2 - l(l+1) \right] \\
a_\mu = a_0 \frac{m_\mathrm{e}}{\mu} \\
\frac{1}{\mu} = \frac{1}{m_\mathrm{e}} + \frac{1}{m_\mathrm{p}}
```

Reference:
- [高柳和夫『朝倉物理学大系 11 原子分子物理学』(2000, 朝倉書店) pp.11-22](https://www.asakura.co.jp/detail.php?book_code=13681)
- [ Quan­tum Me­chan­ics for En­gi­neers by Leon van Dom­me­len](https://web1.eng.famu.fsu.edu/~dommelen/quantum/style_a/nt_rsexp.html)
```""")

@testset "∫r|Rₙₗ(r)|²r²dr = (a₀×mₑ/μ)/2Z × [3n²-l(l+1)]; 1/μ = 1/mₑ + 1/mₚ" begin
  println("  n\t  l\tnumerical         \tanalytical        \t|error|")
  for n in 1:9
  for l in 0:n-1
    numerical  = quadgk(r -> r^3 * HA.R(r,n=n,l=l)^2, 0, Inf, maxevals=10^3)[1]
    analytical = HA.a₀/2/HA.Z * (3*n^2-l*(l+1))
    error = analytical == 0 ? (abs(numerical) < 1e-5 ? 0.0 : Inf) : abs((numerical-analytical)/analytical)
    acceptance = error < 1e-5
    @test acceptance
    @printf("%3d\t%3d\t%.16f\t%.16f\t%.16f%%\t%s\n", n, l, numerical, analytical, error*100, acceptance ? "✔" :  "✗")
  end
  end
end

println("""```
""")


# ∫r²|Rₙₗ(r)|²r²dr = (a₀×mₑ/μ)²/2Z² × n²[5n²+1-3l(l+1)]; 1/μ = 1/mₑ + 1/mₚ


println(raw"""
#### Expected Value of $r^2$

```math
\langle r^2 \rangle
= \int r^2 |R_{n_1 l_1}(r)|^2 r^2 \mathrm{d}r
= \frac{a_\mu^2}{2Z^2} n^2 \left[ 5n^2 + 1 - 3l(l+1) \right] \\
a_\mu = a_0 \frac{m_\mathrm{e}}{\mu} \\
\frac{1}{\mu} = \frac{1}{m_\mathrm{e}} + \frac{1}{m_\mathrm{p}}
```

Reference:
- [高柳和夫『朝倉物理学大系 11 原子分子物理学』(2000, 朝倉書店) pp.11-22](https://www.asakura.co.jp/detail.php?book_code=13681)
- [ Quan­tum Me­chan­ics for En­gi­neers by Leon van Dom­me­len](https://web1.eng.famu.fsu.edu/~dommelen/quantum/style_a/nt_rsexp.html)
```""")

@testset "∫r²|Rₙₗ(r)|²r²dr = (a₀×mₑ/μ)²/2Z² × n²[5n²+1-3l(l+1)]; 1/μ = 1/mₑ + 1/mₚ" begin
  println("  n\t  l\tnumerical         \tanalytical        \t|error|")
  for n in 1:9
  for l in 0:n-1
    numerical  = quadgk(r -> r^4 * HA.R(r,n=n,l=l)^2, 0, Inf, maxevals=10^3)[1]
    analytical = HA.a₀^2/2/HA.Z^2 * n^2*(5*n^2+1-3*l*(l+1))
    error = analytical == 0 ? (abs(numerical) < 1e-5 ? 0.0 : Inf) : abs((numerical-analytical)/analytical)
    acceptance = error < 1e-5
    @test acceptance
    @printf("%3d\t%3d\t%.16f\t%.16f\t%.16f%%\t%s\n", n, l, numerical, analytical, error*100, acceptance ? "✔" :  "✗")
  end
  end
end

println("""```
""")


# <ψₙ|V|ψₙ> / 2 = Eₙ


println(raw"""
#### Virial Theorem

The virial theorem $2\langle T \rangle + \langle V \rangle = 0$ and the definition of Hamiltonian $\langle H \rangle = \langle T \rangle + \langle V \rangle$ derive $\langle H \rangle = \frac{1}{2} \langle V \rangle$ and $\langle H \rangle = -\langle T \rangle$.

```math
\frac{1}{2} \int \psi_n^\ast(x) V(x) \psi_n(x) \mathrm{d}x = E_n
```
```""")

@testset "<ψₙ|V|ψₙ> / 2 = Eₙ" begin
  println("  n\tnumerical         \tanalytical        \t|error|")
  for n in 1:10
    numerical  = quadgk(r -> 4*π*r^2 * conj(HA.ψ(r,0,0, n=n)) * HA.V(r) * HA.ψ(r,0,0, n=n), 0, Inf, maxevals=10^3)[1]
    analytical = HA.E(n=n) * 2
    error = abs((numerical-analytical)/analytical)
    acceptance = error < 1e-5
    @test acceptance
    @printf("%3d\t%.16f\t%.16f\t%.16f%%\t%s\n", n, numerical, analytical, error*100, acceptance ? "✔" :  "✗")
  end
end

println("""```
""")


# <ψₙ₁ₗ₁ₘ₁|ψₙ₂ₗ₂ₘ₂> = δₙ₁ₙ₂δₗ₁ₗ₂δₘ₁ₘ₂


println(raw"""
#### Normalization & Orthogonality of $\psi_n(r,\theta,\varphi)$

```math
\int \psi_i^\ast(r,\theta,\varphi) \psi_j(r,\theta,\varphi) r^2 \mathrm{d}r \mathrm{d}\theta \mathrm{d}\varphi = \delta_{ij}
```
```""")

@testset "<ψₙ₁ₗ₁ₘ₁|ψₙ₂ₗ₂ₘ₂> = δₙ₁ₙ₂δₗ₁ₗ₂δₘ₁ₘ₂" begin
  println(" n1\t n2\t l1\t l2\t m1\t m2\tnumerical         \tanalytical        \t|error|")
  for n1 in 1:3
  for n2 in 1:3
  for l1 in 0:n1-1
  for l2 in 0:n2-1
  for m1 in -l1:l1
  for m2 in -l2:l2
    numerical = real(
      quadgk(phi ->
      quadgk(theta ->
      quadgk(r ->
        r^2 * sin(theta) * conj(HA.ψ(r,theta,phi,n=n1,l=l1,m=m1)) * HA.ψ(r,theta,phi,n=n2,l=l2,m=m2)
      , 0, Inf, maxevals=50)[1]
      , 0, π, maxevals=4)[1]
      , 0, 2π, maxevals=8)[1]
    )
    analytical = (n1 == n2 ? 1 : 0) * (l1 == l2 ? 1 : 0) * (m1 == m2 ? 1 : 0)
    if analytical == 0
      error = abs(numerical) < 1e-2 ? 0.0 : Inf
    else
      error = abs((numerical-analytical)/analytical)
    end
    acceptance = error < 1e-2
    @test acceptance
    @printf("%3d\t%3d\t%3d\t%3d\t%3d\t%3d\t%.16f\t%.16f\t%.16f%%\t%s\n", n1, n2, l1, l2, m1, m2, numerical, analytical, error*100, acceptance ? "✔" :  "✗")
  end
  end
  end
  end
  end
  end
end

println("""```
""")
