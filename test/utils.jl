using Downloads

data_path(fname) = joinpath(pkgdir(CDFDatasets), "data", fname)

# Download test data from URL and cache locally
function download_test_data(url, filename = basename(url))
    cache_dir = joinpath(pkgdir(CDFDatasets), "test", "data")
    mkpath(cache_dir)
    filepath = joinpath(cache_dir, filename)
    if !isfile(filepath)
        @info "Downloading test data: $filename"
        Downloads.download(url, filepath)
    end
    return filepath
end

struct EmptyDiskVector <: DiskArrays.AbstractDiskArray{Float32, 1} end
Base.size(::EmptyDiskVector) = (0,)
DiskArrays.haschunks(::EmptyDiskVector) = DiskArrays.Chunked()
DiskArrays.eachchunk(::EmptyDiskVector) = DiskArrays.GridChunks((DiskArrays.RegularChunks(1, 0, 0),))
DiskArrays.readblock!(::EmptyDiskVector, aout, r...) = aout
