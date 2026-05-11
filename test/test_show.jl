@testset "CDFDataset show" begin
    ds = CDFDataset(data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf"))

    # Test compact show
    str = string(ds)
    @test occursin("omni_coho1hr_merged_mag_plasma", str)
    @test occursin("12 variables", str)

    # Test MIME"text/plain" show
    io = IOBuffer()
    show(io, MIME"text/plain"(), ds)
    str = String(take!(io))
    @test occursin("Group: omni_coho1hr_merged_mag_plasma", str)
    @test occursin("Data variables\n", str)

    # Test limited MIME"text/plain" show
    io = IOBuffer()
    show(IOContext(io, :limit => true), MIME"text/plain"(), ds)
    str = String(take!(io))
    @test occursin("28 attributes: Project, Discipline", str)
    @test occursin("Global attributes\n", str)

    str = sprint(show, ds["BR"]; context = :limit => true)
    @test str == "BR (744) dims=Epoch [BR in RTN (Radial-Tangential-Normal) coordinate system; nT]"
end
