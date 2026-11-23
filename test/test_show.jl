@testset "CDFDataset show" begin
    ds = CDFDataset(data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf"))

    str = string(ds)
    @test occursin("omni_coho1hr_merged_mag_plasma", str)
    @test occursin("12 variables", str)

    str = sprint(show, MIME"text/plain"(), ds)
    @test occursin("Group: omni_coho1hr_merged_mag_plasma", str)
    @test occursin("Data variables\n", str)

    str = sprint(show, MIME"text/plain"(), ds; context = :limit => true)
    @test occursin("28 attributes: Project, Discipline", str)
    @test occursin("Global attributes\n", str)

    str = sprint(show, ds["BR"]; context = :limit => true)
    @test str == "BR (744) dims=Epoch [BR in RTN (Radial-Tangential-Normal) coordinate system; nT]"
    br = variable(ds, "BR"; metadata = Dict("UNITS" => nothing, "CATDESC" => nothing, "FIELDNAM" => "Radial field"))
    @test endswith(sprint(show, br; context = :limit => true), "[Radial field]")
end
