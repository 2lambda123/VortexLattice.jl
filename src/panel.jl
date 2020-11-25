"""
    AbstractPanel{TF}

Supertype of vortex lattice method panel types.
"""
abstract type AbstractPanel{TF} end

"""
    top_left(panel::AbstractPanel)

Return the top left vertex of `panel`
"""
top_left

"""
    top_center(panel::AbstractPanel)

Return the top center vertex of `panel`
"""
top_center

"""
    top_right(panel::AbstractPanel)

Return the top right vertex of `panel`
"""
top_right

"""
    bottom_left(panel::AbstractPanel)

Return the bottom left vertex of `panel`
"""
bottom_left

"""
    bottom_center(panel::AbstractPanel)

Return the bottom center vertex of `panel`
"""
bottom_center

"""
    bottom_right(panel::AbstractPanel)

Return the bottom right vertex of `panel`
"""
bottom_right

"""
    controlpoint(panel::AbstractPanel)

Return the control point of `panel` (typically located at the 3/4 chord)
"""
controlpoint

"""
    normal(panel::AbstractPanel)

Return the normal vector of `panel`
"""
normal

"""
    get_core_size(panel::AbstractPanel)

Return the panel core size
"""
get_core_size

"""
    translate(panel::AbstractPanel, r)

Return a copy of `panel` translated the distance specified by vector `r`
"""
translate(panel::AbstractPanel, r)

"""
    translate(panels::AbstractVector{<:AbstractPanel}, r)

Return a copy of `panels` translated the distance specified by vector `r`
"""
translate(panels::AbstractVector{<:AbstractPanel}, r) = translate.(panels, Ref(r))

"""
    translate!(panels, r)

Translate the panels contained in `panels` the distance specified by vector `r`
"""
function translate!(panels, r)

    for i in eachindex(panels)
        panels[i] = translate(panels[i], r)
    end

    return panels
end

"""
    reflect(panel::AbstractPanel)

Reflects a panel across the y-axis.
"""
reflect(panel::AbstractPanel)

"""
    reflect(panels::AbstractMatrix{<:AbstractPanel})

Reflects panels about the y-axis, preserving panel grid-based ordering
"""
reflect(panels::AbstractMatrix{<:AbstractPanel}) = reflect.(reverse(panels, dims=2))

"""
    panel_induced_velocity(rcp, panel, trailing; kwargs...)

Compute the normalized induced velocity at point `rcp` induced by the top,
bottom, left, and right sides of `panel`.

# Arguments
 - `rcp`: Control point for receiving panel
 - `panel`: Sending panel
 - `trailing`: Flag indicating whether `panel` sheds trailing vortices

# Keyword Arguments
 - `finite_core = false`: Flag indicating whether finite_core model should be applied
 - `reflect = false`: Flag indicating whether `panel` should be reflected across the
    y-axis before calculating induced velocities.  Note that left and right are defined
    prior to performing the reflection
 - `xhat = [1,0,0]`: Direction in which trailing vortices are shed
 - `include_top = true`: Flag to disable induced velocity calculations for the top bound vortex
 - `include_bottom = true`: Flag to disable induced velocity calculations for the bottom bound vortex
    or trailing vortices
 - `include_left = true`: Flag to disable induced velocity calculations for the left bound vortex
 - `include_right = true`: Flag to disable induced velocity calculations for the right bound vortex
"""
panel_induced_velocity(rcp, panel::AbstractPanel, trailing; kwargs...)

"""
    surface_induced_velocity(rcp, surface, Γ; kwargs...)

Returns the induced velocity at `rcp` from the panels in `surface`

# Arguments
 - `rcp`: location where induced velocity is calculated
 - `surface`: Matrix of surface panels of shape (nc, ns) where `nc` is the number of
    chordwise panels and `ns` is the number of spanwise panels
 - `Γ`: Circulation strengths corresponding to `surface`

# Keyword Arguments
 - `symmetric`: Flag indicating whether a mirror image of the panels in `surface`
    should be used when calculating induced velocities.
 - `same_surface`: Flag indicating whether `rcp` corresponds to a panel center
    on `surface`
 - `same_id`: Flag indicating whether `rcp` is on a surface with the same ID as
   `surface`
 - `trailing_vortices`: Flag that may be used to enable/disable trailing vortices
    shed from `surface`
 - `xhat`: direction in which trailing vortices are shed
 - `Ib`: cartesian index corresponding to the location of `rcp` on `surface`,
    assuming `rcp` is located at a panel bound vortex center. (1,1) corresponds
    to the center of the top left panel and (nc, ns) corresponds to the center
    of the bottom right panel.  Setting `Ib` equal to `nothing` indicates that
    `rcp` is not located at a panel bound vortex center, which is the default
 - `Ic`: cartesian index corresponding to the location of `rcp` on `surface`,
    assuming `rcp` is located at a panel corner. (1,1) corresponds to the top
    left corner and (nc+1, ns+1) corresponds to the bottom right corner. Setting
    `Ic` equal to `nothing` indicates that `rcp` is not located at a panel corner,
    which is the default setting
"""
@inline function surface_induced_velocity(rcp, surface, Γ; symmetric, same_surface,
    same_id, trailing_vortices, xhat, Ib=nothing, Ic=nothing)

    TF = promote_type(eltype(rcp), eltype(eltype(surface)), eltype(Γ))

    nc, ns = size(surface)
    Ns = length(surface)
    cs = CartesianIndices(surface)

    finite_core = !same_id
    previous_trailing = false

    Vind = @SVector zeros(TF, 3)
    for j = 1:Ns
        J = cs[j]

        leading_edge = J[1] == 1
        trailing_edge = J[1] == nc
        left_side = J[2] == 1
        right_side = J[2] == ns

        # exclude bound vortices that correspond to the index of `rcp`
        if isnothing(Ib) && isnothing(Ic)
            include_top = true
            include_bottom = true
            include_left = true
            include_right = true
            include_left_trailing = true
            include_right_trailing = true

            if symmetric
                include_top_mirrored = true
                include_bottom_mirrored = true
                include_left_mirrored = true
                include_right_mirrored = true
                include_left_trailing_mirrored = true
                include_right_trailing_mirrored = true
            end
        elseif !isnothing(Ib) && isnothing(Ic)
            include_top = !(same_surface && Ib[1] == J[1] && Ib[2] == J[2])
            include_bottom = !(same_surface && Ib[1] == J[1]+1 && Ib[2] == J[2])
            include_left = true
            include_right = true
            include_left_trailing = true
            include_right_trailing = true

            if symmetric
                # ignore the reflected vortex filaments if they also intersect
                # with the control point, otherwise include the
                include_top_mirrored = include_top || not_on_symmetry_plane(
                    top_left(surface[J]), top_right(surface[J]))
                include_bottom_mirrored = include_bottom || not_on_symmetry_plane(
                    bottom_left(surface[J]), bottom_right(surface[J]))
                include_left_mirrored = true
                include_right_mirrored = true
                include_left_trailing_mirrored = true
                include_right_trailing_mirrored = true
            end
        elseif isnothing(Ib) && !isnothing(Ic)
            vertically_adjacent = same_surface && Ic[1] == J[1] + 1 || Ic[1] == J[1]
            horizontally_adjacent = same_surface && Ic[2] == J[2] + 1 || Ic[2] == J[2]

            include_top = !(horizontally_adjacent && Ic[1] == J[1])
            if on_trailing_edge(surface[J], trailing_edge)
                include_bottom = !(horizontally_adjacent && Ic[1] == nc + 1)
            else
                include_bottom = !(horizontally_adjacent && Ic[1] == J[1]+1)
            end
            include_left = !(vertically_adjacent && Ic[2] == J[2])
            include_right = !(vertically_adjacent && Ic[2] == J[2]+1)
            include_left_trailing = include_left && include_bottom
            include_right_trailing = include_right && include_bottom

            if symmetric
                # ignore the reflected vortex filaments if they also intersect
                # with the control point, otherwise include them
                include_top_mirrored = include_top || not_on_symmetry_plane(
                    top_left(surface[J]), top_right(surface[J]))
                include_bottom_mirrored = include_bottom || not_on_symmetry_plane(
                    bottom_left(surface[J]), bottom_right(surface[J]))
                include_left_mirrored = include_left || not_on_symmetry_plane(
                    top_left(surface[J]), bottom_left(surface[J]))
                include_right_mirrored = include_right || not_on_symmetry_plane(
                    top_right(surface[J]), bottom_right(surface[J]))
                include_left_trailing_mirrored = include_left_trailing ||
                    not_on_symmetry_plane(bottom_left(surface[J]))
                include_right_trailing_mirrored = include_right_trailing ||
                    not_on_symmetry_plane(bottom_right(surface[J]))
            end
        else
            @assert !(!isnothing(Ib) && !isnothing(Ic)) "The control point cannot be located at a corner and a panel bound vortex center"
        end

        # trailing vortices instead of bottom bound vortex?
        trailing = trailing_vortices && on_trailing_edge(surface[J], trailing_edge)

        if finite_core

            # induced velocity from the panel
            vt, vb, vl, vr, vlt, vrt = panel_induced_velocity(rcp, surface[J], trailing;
                finite_core = finite_core,
                reflect = false,
                xhat = xhat,
                include_top = include_top,
                include_bottom = include_bottom,
                include_left = include_left,
                include_right = include_right,
                include_left_trailing = include_left_trailing,
                include_right_trailing = include_right_trailing)

            # add induced velocity from reflected panel if symmetric
            if symmetric

                vt_s, vb_s, vl_s, vr_s, vlt_s, vrt_s = panel_induced_velocity(rcp,
                    surface[J], trailing;
                    finite_core = finite_core,
                    reflect = true,
                    xhat = xhat,
                    include_top = include_top_mirrored,
                    include_bottom = include_bottom_mirrored,
                    include_left = include_left_mirrored,
                    include_right = include_right_mirrored,
                    include_left_trailing = include_left_trailing_mirrored,
                    include_right_trailing = include_right_trailing_mirrored)

                vt += vt_s
                vb += vb_s
                vl += vl_s
                vr += vr_s
                vlt += vlt_s
                vrt += vrt_s
            end

            # add velocity from this panel
            Vind += (vt + vb + vl + vr + vlt + vrt) * Γ[j]

        else
            # use more efficient formulation when finite core is disabled

            # induced velocity from the panel
            vt, vb, vl, vr, vlt, vrt = panel_induced_velocity(rcp, surface[J], trailing;
                finite_core = finite_core,
                reflect = false,
                xhat = xhat,
                include_top = (leading_edge || previous_trailing) && include_top,
                include_bottom = include_bottom,
                include_left = left_side && include_left,
                include_right = include_right,
                include_left_trailing = left_side && include_left_trailing,
                include_right_trailing = include_right_trailing)

            # add induced velocity from reflected panel if symmetric
            if symmetric

                vt_s, vb_s, vl_s, vr_s, vlt_s, vrt_s = panel_induced_velocity(rcp,
                    surface[J], trailing;
                    finite_core = finite_core,
                    reflect = true,
                    xhat = xhat,
                    include_top = (leading_edge || previous_trailing) && include_top_mirrored,
                    include_bottom = include_bottom_mirrored,
                    include_left = left_side && include_left_mirrored,
                    include_right = include_right_mirrored,
                    include_left_trailing = left_side && include_left_trailing_mirrored,
                    include_right_trailing = include_right_trailing_mirrored)

                vt += vt_s
                vb += vb_s
                vl += vl_s
                vr += vr_s
                vlt += vlt_s
                vrt += vrt_s
            end

            # add velocity from this panel (excluding already computed components)
            Vind += (vt + vb + vl + vr + vlt + vrt) * Γ[j]

            # additional contribution from bottom shared edge
            if !(trailing || trailing_edge)
                Vind -= vb * Γ[j+1]
            end

            # additional contribution from right shared edge
            if !right_side
                Vind -= vr * Γ[j+nc]
            end

            # additional contribution from right shared trailing vortex
            if !right_side
                Vind -= vrt * Γ[j+nc]
            end
        end
        previous_trailing = trailing
    end

    return Vind
end

"""
    surface_induced_velocity_derivatives(rcp, surface, Γ, dΓ; kwargs...)

Returns the induced velocity at `rcp` from the panels in `surface` and its
derivatives with respect to the freestream variables

# Arguments
 - `rcp`: location where induced velocity is calculated
 - `surface`: Matrix of surface panels of shape (nc, ns) where `nc` is the number of
    chordwise panels and `ns` is the number of spanwise panels
 - `Γ`: Circulation strengths corresponding to `surface`
 - `dΓ`: Circulation strength derivatives corresponding to `surface`

# Keyword Arguments
 - `symmetric`: Flag indicating whether a mirror image of the panels in `surface`
    should be used when calculating induced velocities.
 - `same_surface`: Flag indicating whether `rcp` corresponds to a panel center
    on `surface`
 - `same_id`: Flag indicating whether `rcp` is on a surface with the same ID as
    `surface`
 - `trailing_vortices`: Flag that may be used to enable/disable trailing vortices
    shed from `surface`
 - `xhat`: direction in which trailing vortices are shed
 - `I`: cartesian index corresponding to the location of `rcp` on `surface`. (1,1)
    corresponds to the center of the top left panel and (nc, ns) corresponds
    to the center of the bottom right panel.  By default, `rcp` is not assumed
    to correspond to a panel center on `surface`.
"""
@inline function surface_induced_velocity_derivatives(rcp, surface, Γ, dΓ;
    symmetric, same_surface, same_id, trailing_vortices, xhat, I=CartesianIndex(-1, -1))

    TF = promote_type(eltype(rcp), eltype(eltype(surface)))

    Ns = length(surface)
    nc, ns = size(surface)
    cs = CartesianIndices(surface)

    finite_core = !same_id
    previous_trailing = false

    # unpack derivatives
    Γ_a, Γ_b, Γ_p, Γ_q, Γ_r = dΓ

    Vind = @SVector zeros(TF, 3)

    Vind_a = @SVector zeros(TF, 3)
    Vind_b = @SVector zeros(TF, 3)
    Vind_p = @SVector zeros(TF, 3)
    Vind_q = @SVector zeros(TF, 3)
    Vind_r = @SVector zeros(TF, 3)

    for j = 1:Ns
        J = cs[j]

        leading_edge = J[1] == 1
        trailing_edge = J[1] == nc
        left_side = J[2] == 1
        right_side = J[2] == ns

        # exclude bound vortices that correspond to the index of `rcp`
        include_top = !(same_surface && I[1] == J[1] && I[2] == J[2])
        include_bottom = !(same_surface && I[1] == J[1]+1 && I[2] == J[2])

        # trailing vortices instead of bottom bound vortex?
        trailing = trailing_vortices && on_trailing_edge(surface[J], trailing_edge)

        if finite_core

            # induced velocity from the panel
            vt, vb, vl, vr, vlt, vrt = panel_induced_velocity(rcp, surface[J],
                trailing; finite_core = finite_core, reflect = false, xhat = xhat,
                include_top=include_top, include_bottom=include_bottom)

            # add induced velocity from reflected panel if symmetric
            if symmetric
                include_top_mirrored = include_top || not_on_symmetry_plane(
                    top_left(surface[J]), top_right(surface[J]))

                include_bottom_mirrored = include_bottom || not_on_symmetry_plane(
                    bottom_left(surface[J]), bottom_right(surface[J]))

                vt_s, vb_s, vl_s, vr_s, vlt_s, vrt_s = panel_induced_velocity(rcp,
                    surface[J], trailing;
                    finite_core = finite_core, reflect = true, xhat = xhat,
                    include_top=include_top_mirrored, include_bottom=include_bottom_mirrored)

                vt += vt_s
                vb += vb_s
                vl += vl_s
                vr += vr_s
                vlt += vlt_s
                vrt += vrt_s
            end

            Vhat = vt + vb + vl + vr + vlt + vrt

            # add velocity from this panel (excluding already computed components)
            Vind += Vhat * Γ[j]

            # and its derivatives
            Vind_a += Vhat * Γ_a[j]
            Vind_b += Vhat * Γ_b[j]
            Vind_p += Vhat * Γ_p[j]
            Vind_q += Vhat * Γ_q[j]
            Vind_r += Vhat * Γ_r[j]

        else
            # use more efficient formulation when finite core is disabled

            # induced velocity from the panel
            vt, vb, vl, vr, vlt, vrt = panel_induced_velocity(rcp, surface[J],
                trailing; finite_core = false, reflect = false, xhat = xhat,
                include_top = include_top && (leading_edge || previous_trailing),
                include_bottom=include_bottom, include_left=left_side,
                include_left_trailing=left_side)

            # add induced velocity from reflected panel if symmetric
            if symmetric
                include_top_mirrored = include_top || not_on_symmetry_plane(
                    top_left(surface[J]), top_right(surface[J]))

                include_bottom_mirrored = include_bottom || not_on_symmetry_plane(
                    bottom_left(surface[J]), bottom_right(surface[J]))

                vt_s, vb_s, vl_s, vr_s, vlt_s, vrt_s = panel_induced_velocity(rcp,
                    surface[J], trailing;
                    finite_core = false,  reflect = true, xhat = xhat,
                    include_top=include_top_mirrored && (leading_edge || previous_trailing),
                    include_bottom=include_bottom_mirrored,
                    include_left=left_side, include_left_trailing=left_side)

                vt += vt_s
                vb += vb_s
                vl += vl_s
                vr += vr_s
                vlt += vlt_s
                vrt += vrt_s
            end

            Vhat = vt + vb + vl + vr + vlt + vrt

            # add velocity from this panel (excluding already computed components)
            Vind += Vhat * Γ[j]

            # and its derivatives
            Vind_a += Vhat * Γ_a[j]
            Vind_b += Vhat * Γ_b[j]
            Vind_p += Vhat * Γ_p[j]
            Vind_q += Vhat * Γ_q[j]
            Vind_r += Vhat * Γ_r[j]

            # additional contribution from bottom shared edge
            if !(trailing || trailing_edge)
                Vind -= vb * Γ[j+1]

                Vind_a -= vb * Γ_a[j+1]
                Vind_b -= vb * Γ_b[j+1]
                Vind_p -= vb * Γ_p[j+1]
                Vind_q -= vb * Γ_q[j+1]
                Vind_r -= vb * Γ_r[j+1]
            end

            # additional contribution from right shared edge
            if !right_side
                Vind -= vr * Γ[j+nc]

                Vind_a -= vr * Γ_a[j+nc]
                Vind_b -= vr * Γ_b[j+nc]
                Vind_p -= vr * Γ_p[j+nc]
                Vind_q -= vr * Γ_q[j+nc]
                Vind_r -= vr * Γ_r[j+nc]
            end

            # additional contribution from right shared trailing vortex
            if !right_side
                Vind -= vrt * Γ[j+nc]

                Vind_a -= vrt * Γ_a[j+nc]
                Vind_b -= vrt * Γ_b[j+nc]
                Vind_p -= vrt * Γ_p[j+nc]
                Vind_q -= vrt * Γ_q[j+nc]
                Vind_r -= vrt * Γ_r[j+nc]
            end
        end
        previous_trailing = trailing
    end

    dVind = (Vind_a, Vind_b, Vind_p, Vind_q, Vind_r)

    return Vind, dVind
end

"""
    panel_circulation(panel, Γ1, Γ2)

Return the circulation on `panel` given the circulation strength of the previous
bound vortex Γ1 and the current bound vortex Γ2
"""
panel_circulation

"""
   trailing_edge_circulation(surface, Γ)

Return the trailing edge bound vortex circulation on `surface` given the
circulation in a chordwise strip `Γ`.
"""
trailing_edge_circulation

"""
    left_center(panel::AbstractPanel)

Return the center of the left bound vortex on `panel`
"""
@inline left_center(panel::AbstractPanel) = (top_left(panel) + bottom_left(panel))/2

"""
    right_center(panel::AbstractPanel)

Return the center of the right bound vortex on `panel`
"""
@inline right_center(panel::AbstractPanel) = (top_right(panel) + bottom_right(panel))/2

"""
    top_vector(panel::AbstractPanel)

Returns the path of the top bound vortex for `panel`
"""
@inline top_vector(panel::AbstractPanel) = top_right(panel) - top_left(panel)

"""
    left_vector(panel)

Return the path of the left bound vortex for `panel`
"""
@inline left_vector(panel::AbstractPanel) = top_left(panel) - bottom_left(panel)

"""
    right_vector(panel)

Return the path of the right bound vortex for `panel`
"""
@inline right_vector(panel::AbstractPanel) = bottom_right(panel) - top_right(panel)

"""
    bottom_vector(panel)

Return the path of the bottom bound vortex for `panel`
"""
@inline bottom_vector(panel::AbstractPanel) = bottom_left(panel) - bottom_right(panel)

# --- Horseshoe Vortex Implementation --- #

"""
    Horseshoe{TF}

Horseshoe shaped panel element with trailing vortices that extend in the +x
direction to the trailing edge, and then into the farfield.

**Fields**
 - `rl`: position of the left side of the bound vortex
 - `rc`: position of the center of the bound vortex
 - `rr`: position of the right side of the bound vortex
 - `rcp`: position of the panel control point
 - `ncp`: normal vector at the panel control point
 - `xl_te`: x-distance from the left side of the bound vortex to the trailing edge
 - `xc_te`: x-distance from the center of the bound vortex to the trailing edge
 - `xr_te`: x-distance from the right side of the bound vortex to the trailing edge
 - `core_size`: finite core size
"""
struct Horseshoe{TF} <: AbstractPanel{TF}
    rl::SVector{3, TF}
    rc::SVector{3, TF}
    rr::SVector{3, TF}
    rcp::SVector{3, TF}
    ncp::SVector{3, TF}
    xl_te::TF
    xc_te::TF
    xr_te::TF
    core_size::TF
end

"""
    Horseshoe(rl, rr, rcp, xl_te, xc_te, xr_te, theta; rc)

Construct and return a horseshoe vortex panel.

**Arguments**
- `rl`: position of the left side of the bound vortex
- `rr`: position of the right side of the bound vortex
- `rcp`: position of the panel control point
- `ncp`: normal vector at the panel control point
- `xl_te`: x-distance from the left side of the bound vortex to the trailing edge
- `xr_te`: x-distance from the right side of the bound vortex to the trailing edge
- `core_size`: finite core size
- `rc`: (optional) position of the center of the bound vortex, defaults to `(rl+rr)/2`
- `xc_te`: (optional) x-distance from the center of the bound vortex to the
    trailing edge, defaults to `(xl_te+xr_te)/2`
"""
Horseshoe(rl, rr, rcp, ncp, xl_te, xr_te, core_size; rc=(rl+rr)/2, xc_te=(xl_te+xr_te)/2) = Horseshoe(rl, rc, rr, rcp, ncp, xl_te, xc_te, xr_te, core_size)

function Horseshoe(rl, rc, rr, rcp, ncp, xl_te, xc_te, xr_te, core_size)
    TF = promote_type(eltype(rl), eltype(rc), eltype(rr), eltype(rcp), eltype(ncp), typeof(xl_te), typeof(xc_te), typeof(xr_te), typeof(core_size))
    return Horseshoe{TF}(rl, rc, rr, rcp, ncp, xl_te, xc_te, xr_te, core_size)
end

@inline Base.eltype(::Type{Horseshoe{TF}}) where TF = TF
@inline Base.eltype(::Horseshoe{TF}) where TF = TF

@inline top_left(panel::Horseshoe) = panel.rl

@inline top_center(panel::Horseshoe) = panel.rc

@inline top_right(panel::Horseshoe) = panel.rr

@inline bottom_left(panel::Horseshoe) = panel.rl + SVector(panel.xl_te, 0, 0)

@inline bottom_center(panel::Horseshoe) = panel.rc + SVector(panel.xc_te, 0, 0)

@inline bottom_right(panel::Horseshoe) = panel.rr +  SVector(panel.xr_te, 0, 0)

@inline controlpoint(panel::Horseshoe) = panel.rcp

@inline normal(panel::Horseshoe) = panel.ncp

@inline get_core_size(panel::Horseshoe) = panel.core_size

@inline on_trailing_edge(panel::Horseshoe, trailing_edge) = true

@inline panel_induced_velocity(rcp, panel::Horseshoe, trailing;
    kwargs...) = horseshoe_induced_velocity(rcp, top_left(panel), top_right(panel),
    bottom_left(panel), bottom_right(panel), trailing; kwargs...,
    core_size=get_core_size(panel))

@inline panel_circulation(panel::Horseshoe, Γ1, Γ2) = Γ2

@inline trailing_edge_circulation(surface::AbstractMatrix{<:Horseshoe}, Γ) = sum(Γ)

@inline function translate(panel::Horseshoe, r)

    rl = panel.rl + r
    rc = panel.rc + r
    rr = panel.rr + r
    rcp = panel.rcp + r
    ncp = panel.ncp
    xl_te = panel.xl_te
    xc_te = panel.xc_te
    xr_te = panel.xr_te
    core_size = panel.core_size

    return Horseshoe(rl, rc, rr, rcp, ncp, xl_te, xc_te, xr_te, core_size)
end

@inline function reflect(panel::Horseshoe)

    rl = flipy(panel.rr)
    rc = flipy(panel.rc)
    rr = flipy(panel.rl)
    rcp = flipy(panel.rcp)
    ncp = flipy(panel.ncp)
    xl_te = panel.xr_te
    xc_te = panel.xc_te
    xr_te = panel.xl_te
    core_size = panel.core_size

    return Horseshoe(rl, rc, rr, rcp, ncp, xl_te, xc_te, xr_te, core_size)
end

# --- Vortex Ring Implementation --- #

"""
    Ring{TF}

Vortex ring shaped panel element.

**Fields**
 - `rtl`: position of the left side of the top bound vortex
 - `rtc`: position of the center of the top bound vortex
 - `rtr`: position of the right side of the top bound vortex
 - `rbl`: position of the left side of the bottom bound vortex
 - `rbc`: position of the center of the bottom bound vortex
 - `rbr`: position of the right side of the bottom bound vortex
 - `rcp`: position of the panel control point
 - `ncp`: normal vector at the panel control point
 - `core_size`: finite core size
"""
struct Ring{TF} <: AbstractPanel{TF}
    rtl::SVector{3, TF}
    rtc::SVector{3, TF}
    rtr::SVector{3, TF}
    rbl::SVector{3, TF}
    rbc::SVector{3, TF}
    rbr::SVector{3, TF}
    rcp::SVector{3, TF}
    ncp::SVector{3, TF}
    core_size::TF
end

"""
    Ring(rtl, rtr, rbl, rbr, rcp, ncp, core_size; rtc, rbc)

Construct and return a vortex ring panel.

**Arguments**
 - `rtl`: position of the left side of the top bound vortex
 - `rtr`: position of the right side of the top bound vortex
 - `rbl`: position of the left side of the bottom bound vortex
 - `rbr`: position of the right side of the bottom bound vortex
 - `rcp`: position of the panel control point
 - `ncp`: normal vector at the panel control point
 - `core_size`: core_size length for finite core calculations
 - `rtc`: (optional) position of the center of the top bound vortex, defaults to `(rtl+rtr)/2`
 - `rbc`: (optional) position of the center of the bottom bound vortex, defaults to `(rbl+rbr)/2`
"""
Ring(rtl, rtr, rbl, rbr, rcp, ncp, core_size; rtc=(rtl+rtr)/2, rbc=(rbl+rbr)/2) =
    Ring(rtl, rtc, rtr, rbl, rbc, rbr, rcp, ncp, core_size)

function Ring(rtl, rtc, rtr, rbl, rbc, rbr, rcp, ncp, core_size)
    TF = promote_type(eltype(rtl), eltype(rtc), eltype(rtr), eltype(rbl), eltype(rbc), eltype(rbr), eltype(rcp), eltype(ncp), typeof(core_size))
    return Ring{TF}(rtl, rtc, rtr, rbl, rbc, rbr, rcp, ncp, core_size)
end

@inline Base.eltype(::Type{Ring{TF}}) where TF = TF
@inline Base.eltype(::Ring{TF}) where TF = TF

@inline controlpoint(panel::Ring) = panel.rcp

@inline normal(panel::Ring) = panel.ncp

@inline midpoint(panel::Ring) = panel.rtc

@inline top_left(panel::Ring) = panel.rtl

@inline top_center(panel::Ring) = panel.rtc

@inline top_right(panel::Ring) = panel.rtr

@inline bottom_left(panel::Ring) = panel.rbl

@inline bottom_center(panel::Ring) = panel.rbc

@inline bottom_right(panel::Ring) = panel.rbr

@inline get_core_size(panel::Ring) = panel.core_size

@inline on_trailing_edge(panel::Ring, trailing_edge) = trailing_edge

@inline panel_induced_velocity(rcp, panel::Ring, trailing; kwargs...) =
    ring_induced_velocity(rcp, top_left(panel), top_right(panel), bottom_left(panel),
    bottom_right(panel), trailing; kwargs...,
    core_size=get_core_size(panel))

@inline panel_circulation(panel::Ring, Γ1, Γ2) = Γ2 - Γ1

@inline trailing_edge_circulation(surface::AbstractMatrix{<:Ring}, Γ) = Γ[end]

@inline function translate(panel::Ring, r)

    rtl = panel.rtl + r
    rtc = panel.rtc + r
    rtr = panel.rtr + r
    rbl = panel.rbl + r
    rbc = panel.rbc + r
    rbr = panel.rbr + r
    rcp = panel.rcp + r
    ncp = panel.ncp
    core_size = panel.core_size

    return Ring(rtl, rtc, rtr, rbl, rbc, rbr, rcp, ncp, core_size)
end

@inline function reflect(panel::Ring)

    rtl = flipy(panel.rtr)
    rtc = flipy(panel.rtc)
    rtr = flipy(panel.rtl)
    rbl = flipy(panel.rbr)
    rbc = flipy(panel.rbc)
    rbr = flipy(panel.rbl)
    rcp = flipy(panel.rcp)
    ncp = flipy(panel.ncp)
    core_size = panel.core_size

    return Ring(rtl, rtc, rtr, rbl, rbc, rbr, rcp, ncp, core_size)
end

# --- internal functions --- #

"""
    flipy(r)

Flip sign of y-component of vector `r` (used for symmetry)
"""
@inline flipy(r) = SVector{3}(r[1], -r[2], r[3])



"""
    on_symmetry_plane(args...; tol=eps())

Test whether points in `args` are on the symmetry plane (y = 0)
"""
on_symmetry_plane

on_symmetry_plane(r; tol=eps()) = isapprox(r[2], 0.0, atol=tol)

@inline function on_symmetry_plane(r, args...; tol=eps())
    return on_symmetry_plane(r; tol=tol) && on_symmetry_plane(args...; tol=tol)
end

"""
    not_on_symmetry_plane(args...; tol=eps())

Test whether and of the points in `args` are not on the symmetry plane (y = 0)
"""
not_on_symmetry_plane(args...; tol=eps()) = !on_symmetry_plane(args...; tol=tol)

"""
    bound_induced_velocity(r1, r2, finite_core, core_size)

Compute the induced velocity (per unit circulation) for a bound vortex, at a
control point located at `r1` relative to the start of the bound vortex and `r2`
relative to the end of the bound vortex.
"""
@inline function bound_induced_velocity(r1, r2, finite_core, core_size)

    nr1 = norm(r1)
    nr2 = norm(r2)

    if finite_core
        rdot = dot(r1, r2)
        r1s, r2s, εs = nr1^2, nr2^2, core_size^2
        f1 = cross(r1, r2)/(r1s*r2s - rdot^2 + εs*(r1s + r2s - 2*nr1*nr2))
        f2 = (r1s - rdot)/sqrt(r1s + εs) + (r2s - rdot)/sqrt(r2s + εs)
    else
        f1 = cross(r1, r2)/(nr1*nr2 + dot(r1, r2))
        f2 = (1/nr1 + 1/nr2)
    end

    Vhat = (f1*f2)/(4*pi)

    return Vhat
end

"""
    trailing_induced_velocity(r, xhat, finite_core, core_size)

Compute the induced velocity (per unit circulation) for a vortex trailing in
the `xhat` direction, at a control point located at `r` relative to the start of the
trailing vortex.
"""
@inline function trailing_induced_velocity(r, xhat, finite_core, core_size)

    nr = norm(r)
    rdot = dot(r, xhat)

    if finite_core
        εs = core_size^2
        tmp = εs/(nr + rdot)
        f = cross(r, xhat)/(nr - rdot + tmp)/nr
    else
        f = cross(r, xhat)/(nr - rdot)/nr
    end

    Vhat = -f/(4*pi)

    return Vhat
end

"""
    horseshoe_induced_velocity(rcp, rtl, rtr, rbl, rbr, trailing; kwargs...)

Computes the normalized induced velocity at point `rcp` caused by the top, bottom,
left, right, left trailing, and right trailing sides of a horseshoe vortex.  The
induced velocity for each side of the bound vortex is normalized by the vortex
filament strength.

# Arguments
 - `rcp`: Control point at which induced velocities are calculated
 - `rtl`: Top left corner of the horseshoe vortex
 - `rtr`: Top right corner of the horseshoe vortex
 - `rbl`: Bottom left corner of the horseshoe vortex, the location where the left
    trailing vortex is shed into the freestream
 - `rbr`: Bottom right corner of the horseshoe vortex, the location where the right
    trailing vortex is shed into the freestream
 - `trailing`: Flag indicating whether trailing vortices are shed from this panel

# Keyword Arguments
 - `finite_core = false`: Flag indicating whether finite_core model should be applied
 - `core_size = 0.0`: Finite core size
 - `reflect = false`: Flag indicating whether `panel` should be reflected across the
    y-axis before calculating induced velocities.  Note that left and right are defined
    prior to performing the reflection
 - `xhat = [1,0,0]`: Direction in which trailing vortices are shed
 - `include_top`: Flag to disable induced velocity calculations for the top bound vortex
 - `include_left`: Flag to disable induced velocity calculations for the left bound vortex
 - `include_right`: Flag to disable induced velocity calculations for the right bound vortex
 - `include_left_trailing`: Flag to disable induced velocity calculations for the left trailing vortex
 - `include_right_trailing`: Flag to disable induced velocity calculations for the right trailing vortex
"""
@inline horseshoe_induced_velocity(rcp, rtl, rtr, rbl, rbr, trailing; kwargs...) =
    ring_induced_velocity(rcp, rtl, rtr, rbl, rbr, trailing; kwargs...)

"""
    ring_induced_velocity(rcp, rtl, rtr, rbl, rbr, trailing; kwargs...)

Computes the normalized induced velocity at point `rcp` caused by the top, bottom,
left, right, left trailing, and right trailing sides of a vortex ring panel.  The
induced velocity for each side of the bound vortex is normalized by the vortex
filament strength.

# Arguments
 - `rcp`: Control point at which induced velocities are calculated
 - `rtl`: Top left corner of the vortex ring
 - `rtr`: Top right corner of the vortex ring
 - `rbl`: Bottom left corner of the vortex ring
 - `rbr`: Bottom right corner of the vortex ring
 - `trailing`: Flag indicating whether trailing vortices are shed from the panel

# Keyword Arguments
 - `finite_core = false`: Flag indicating whether finite_core model should be applied
 - `core_size = 0.0`: Finite core size
 - `reflect = false`: Flag indicating whether `panel` should be reflected across the
    y-axis before calculating induced velocities.  Note that left and right are defined
    prior to performing the reflection
 - `xhat = [1,0,0]`: Direction in which trailing vortices are shed if `trailing = true`
 - `include_top`: Flag to disable induced velocity calculations for the top bound vortex
 - `include_bottom`: Flag to disable induced velocity calculations for the bottom bound vortex
    (or trailing vortices if `trailing=true`)
 - `include_left`: Flag to disable induced velocity calculations for the left bound vortex
 - `include_right`: Flag to disable induced velocity calculations for the right bound vortex
 - `include_left_trailing`: Flag to disable induced velocity calculations for the left trailing vortex
 - `include_right_trailing`: Flag to disable induced velocity calculations for the right trailing vortex
"""
@inline function ring_induced_velocity(rcp, rtl, rtr, rbl, rbr, trailing; finite_core=false,
    core_size=0.0, reflect=false, xhat=SVector(1, 0, 0),
    include_top=true, include_bottom=true, include_left=true, include_right=true,
    include_left_trailing=true, include_right_trailing=true)

    TF = promote_type(eltype(rcp), eltype(rtl), eltype(rtr), eltype(rbl), eltype(rbr))

    if reflect
        rtl = flipy(rtl)
        rtr = flipy(rtr)
        rbl = flipy(rbl)
        rbr = flipy(rbr)

        # return no contributions if the reflected panel lies on the symmetry plane
        if on_symmetry_plane(rtl, rtr, rbl, rbr)
            vt = SVector{3, TF}(0, 0, 0)
            vb = SVector{3, TF}(0, 0, 0)
            vl = SVector{3, TF}(0, 0, 0)
            vr = SVector{3, TF}(0, 0, 0)
            vlt = SVector{3, TF}(0, 0, 0)
            vrt = SVector{3, TF}(0, 0, 0)
            return vt, vb, vl, vr, vlt, vrt
        end
    end

    # distance to control point from each corner
    r11 = rcp - rtl
    r12 = rcp - rtr
    r21 = rcp - rbl
    r22 = rcp - rbr

    if include_top && rtl != rtr
        vt = bound_induced_velocity(r11, r12, finite_core, core_size)
    else
        vt = SVector{3, TF}(0, 0, 0)
    end

    if include_bottom && !trailing && rbl != rbr
        vb = bound_induced_velocity(r22, r21, finite_core, core_size)
    else
        vb = SVector{3, TF}(0, 0, 0)
    end

    if include_left && rtl != rbl
        vl = bound_induced_velocity(r21, r11, finite_core, core_size)
    else
        vl = SVector{3, TF}(0, 0, 0)
    end

    if include_right && rtr != rbr
        vr = bound_induced_velocity(r12, r22, finite_core, core_size)
    else
        vr = SVector{3, TF}(0, 0, 0)
    end

    if include_left_trailing && trailing && rbl != rbr
        vlt = -trailing_induced_velocity(r21, xhat, finite_core, core_size)
    else
        vlt = SVector{3, TF}(0, 0, 0)
    end

    if include_right_trailing && trailing && rbl != rbr
        vrt = trailing_induced_velocity(r22, xhat, finite_core, core_size)
    else
        vrt = SVector{3, TF}(0, 0, 0)
    end

    if reflect
        # define circulation direction in same direction on both sides
        vt = -vt
        vb = -vb
        vl = -vl
        vr = -vr
        vlt = -vlt
        vrt = -vrt
    end

    return vt, vb, vl, vr, vlt, vrt
end
