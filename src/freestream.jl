"""
    Freestream(alpha, beta, Omega, additional_velocity=nothing)

Defines the freestream properties.

**Arguments**
- `alpha`: angle of attack (rad)
- `beta`: sideslip angle (rad)
- `Omega`: rotation vector (p, q, r) of the body frame about the center of
    gravity, divided by the current freestream velocity
- `additional_velocity`: a function of the form: V = additional_velocity(r) which returns
    the additional velocity `V` (divided by the current freestream velocity)
    at position `r`.  Defaults to `nothing`.
"""
struct Freestream{TF, TV}
    alpha::TF
    beta::TF
    Omega::SVector{3, TF}
    additional_velocity::TV
end

function Freestream(alpha, beta, Omega, additional_velocity = nothing)
    TF = promote_type(typeof(alpha), typeof(beta), eltype(Omega))
    return Freestream{TF, typeof(additional_velocity)}(alpha, beta, Omega, additional_velocity)
end

Base.eltype(::Type{Freestream{TF, TV}}) where {TF,TV} = TF
Base.eltype(::Freestream{TF, TV}) where {TF,TV} = TF

"""
    body_to_stability(freestream)

Construct a rotation matrix from the body axis to the stability axis.
"""
function body_to_stability(fs::Freestream)
    sa, ca = sincos(fs.alpha)
    return body_to_stability(sa, ca)
end

body_to_stability(sa, ca) = @SMatrix [ca 0 sa; 0 1 0; -sa 0 ca]

"""
    body_to_stability_alpha(freestream)

Construct a rotation matrix from the body axis to the stability axis and its
derivative with respect to `alpha`
"""
body_to_stability_alpha

function body_to_stability_alpha(fs::Freestream)
    sa, ca = sincos(fs.alpha)
    return body_to_stability_alpha(sa, ca)
end

function body_to_stability_alpha(sa, ca)

    R = body_to_stability(sa, ca)

    R_a = @SMatrix [-sa 0 ca; 0 0 0; -ca 0 -sa]

    return R, R_a
end

"""
    stability_to_body(freestream)

Construct a rotation matrix from the stability axis to the body axis
"""
function stability_to_body(fs::Freestream)
    sa, ca = sincos(fs.alpha)
    return stability_to_body(sa, ca)
end

stability_to_body(sa, ca) = body_to_stability(sa, ca)'

"""
    stability_to_body(freestream)

Construct a rotation matrix from the stability axis to the body axis and its
derivative with respect to `alpha`
"""
function stability_to_body_alpha(fs::Freestream)
    sa, ca = sincos(fs.alpha)
    return stability_to_body_alpha(sa, ca)
end

function stability_to_body_alpha(sa, ca)

    R, R_a = body_to_stability_alpha(sa, ca)

    return R', R_a'
end

"""
    stability_to_wind(freestream)

Construct a rotation matrix from the stability axis to the wind axis
"""
stability_to_wind

function stability_to_wind(fs::Freestream)
    sb, cb = sincos(fs.beta)
    return stability_to_wind(sb, cb)
end

stability_to_wind(sb, cb) = @SMatrix [cb -sb 0; sb cb 0; 0 0 1]

"""
    stability_to_wind_beta(freestream)

Construct a rotation matrix from the stability axis to the wind axis and its
derivative with respect to `beta`
"""
stability_to_wind_beta

function stability_to_wind_beta(fs::Freestream)
    sb, cb = sincos(fs.beta)
    return stability_to_wind_beta(sb, cb)
end

function stability_to_wind_beta(sb, cb)

    R = stability_to_wind(sb, cb)

    R_b = @SMatrix [-sb -cb 0; cb -sb 0; 0 0 0]

    return R, R_b
end

"""
    wind_to_stability(freestream)

Construct a rotation matrix from the wind axis to the stability axis
"""
function wind_to_stability(fs::Freestream)
    sb, cb = sincos(fs.beta)
    return wind_to_stability(sb, cb)
end

wind_to_stability(sb, cb) = stability_to_wind(sb, cb)'

"""
    wind_to_stability_beta(freestream)

Construct a rotation matrix from the wind axis to the stability axis and its
derivative with respect to `beta`
"""
function wind_to_stability_beta(fs::Freestream)
    sb, cb = sincos(fs.beta)
    return wind_to_stability_beta(sb, cb)
end

function wind_to_stability_beta(sb, cb)

    R, R_b = stability_to_wind_beta(sb, cb)

    return R', R_b'
end

"""
    body_to_wind(freestream)

Construct a rotation matrix from the body axis to the wind axis
"""
function body_to_wind(fs::Freestream)
    sa, ca = sincos(fs.alpha)
    sb, cb = sincos(fs.beta)
    return body_to_wind(sa, ca, sb, cb)
end

function body_to_wind(sa, ca, sb, cb)

    Ra = body_to_stability(sa, ca)

    Rb = stability_to_wind(sb, cb)

    return Rb*Ra
end

"""
    body_to_wind_derivatives(freestream)

Construct a rotation matrix from the body axis to the wind axis and its
derivatives with respect to `alpha` and `beta`
"""
function body_to_wind_derivatives(fs::Freestream)
    sa, ca = sincos(fs.alpha)
    sb, cb = sincos(fs.beta)
    return body_to_wind_derivatives(sa, ca, sb, cb)
end

function body_to_wind_derivatives(sa, ca, sb, cb)

    Ra, Ra_a = body_to_stability_alpha(sa, ca)

    Rb, Rb_b = stability_to_wind_beta(sb, cb)

    R = Rb*Ra
    R_a = Rb*Ra_a
    R_b = Rb_b*Ra

    return R, R_a, R_b
end

"""
    wind_to_body(freestream)

Construct a rotation matrix from the wind axis to the body axis
"""
function wind_to_body(fs::Freestream)
    sa, ca = sincos(fs.alpha)
    sb, cb = sincos(fs.beta)
    return wind_to_body(sa, ca, sb, cb)
end

wind_to_body(sa, ca, sb, cb) = body_to_wind(sa, ca, sb, cb)'

"""
    wind_to_body_derivatives(freestream)

Construct a rotation matrix from the wind axis to the body axis and its derivatives
with respect to `alpha` and `beta`
"""
function wind_to_body_derivatives(fs::Freestream)
    sa, ca = sincos(fs.alpha)
    sb, cb = sincos(fs.beta)
    return wind_to_body_derivatives(sa, ca, sb, cb)
end

function wind_to_body_derivatives(sa, ca, sb, cb)

    R, R_a, R_b = body_to_wind_derivatives(sa, ca, sb, cb)

    return R', R_a', R_b'
end

"""
    freestream_velocity(freestream)

Computes the freestream velocity
"""
function freestream_velocity(freestream)

    sa, ca = sincos(freestream.alpha)
    sb, cb = sincos(freestream.beta)

    return freestream_velocity(sa, ca, sb, cb)
end

freestream_velocity(sa, ca, sb, cb) = VINF*SVector(ca*cb, -sb, sa*cb)

"""
    freestream_velocity_derivatives(freestream)

Computes the freestream velocity
"""
function freestream_velocity_derivatives(freestream)

    sa, ca = sincos(freestream.alpha)
    sb, cb = sincos(freestream.beta)

    return freestream_velocity_derivatives(sa, ca, sb, cb)
end

function freestream_velocity_derivatives(sa, ca, sb, cb)
    V = VINF*SVector(ca*cb, -sb, sa*cb)
    V_a = VINF*SVector(-sa*cb, 0, ca*cb)
    V_b = VINF*SVector(-ca*sb, -cb, -sa*sb)
    return V, V_a, V_b
end

"""
    external_velocity(freestream, r, rref)

Compute the external velocity at location `r`
"""
function external_velocity(freestream, r, rref)

    sa, ca = sincos(freestream.alpha)
    sb, cb = sincos(freestream.beta)
    Ω = freestream.Omega
    fv = freestream.additional_velocity

    return external_velocity(sa, ca, sb, cb, Ω, fv, r, rref)
end

function external_velocity(sa, ca, sb, cb, Ω, fv, r, rref)

    Vext = freestream_velocity(sa, ca, sb, cb)

    # add velocity due to body rotation
    Vext += VINF*cross(r - rref, Ω)  # unnormalize

    # add contribution due to additional velocity field
    if !isnothing(fv)
        Vext += VINF*fv(r)  # unnormalize
    end

    return Vext
end

"""
    external_velocity_derivatives(freestream, r, rref)

Compute the external velocity at location `r` and its derivatives with respect
to (alpha, beta, p, q, r)
"""
function external_velocity_derivatives(freestream, r, rref)

    sa, ca = sincos(freestream.alpha)
    sb, cb = sincos(freestream.beta)
    Ω = freestream.Omega
    fv = freestream.additional_velocity

    return external_velocity_derivatives(sa, ca, sb, cb, Ω, fv, r, rref)
end

function external_velocity_derivatives(sa, ca, sb, cb, Ω, fv, r, rref)

    # start with uniform velocity field
    Vext, Vext_a, Vext_b = freestream_velocity_derivatives(sa, ca, sb, cb)

    # add velocity due to body rotation
    rv = r - rref
    Vext -= VINF*cross(Ω, rv)  # unnormalize
    Vext_p = VINF*SVector(0, rv[3], -rv[2])
    Vext_q = VINF*SVector(-rv[3], 0, rv[1])
    Vext_r = VINF*SVector(rv[2], -rv[1], 0)

    # add contribution due to additional velocity field
    if !isnothing(fv)
        Vext += VINF*fv(r)  # unnormalize
    end

    # package derivatives
    dVext = (Vext_a, Vext_b, Vext_p, Vext_q, Vext_r)

    return Vext, dVext
end
