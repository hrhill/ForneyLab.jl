module EqualityTest

using Base.Test
using ForneyLab
import ForneyLab: outboundType, isApplicable, SPEqualityGaussian, SPEqualityGamma


#-------------
# Update rules
#-------------

@testset "SPEqualityGaussian" begin
    @test SPEqualityGaussian <: SumProductRule{Equality}
    @test outboundType(SPEqualityGaussian) == Message{Gaussian}
    @test isApplicable(SPEqualityGaussian, [Message{Gaussian}, Message{Gaussian}, Void]) 
    @test isApplicable(SPEqualityGaussian, [Message{Gaussian}, Void, Message{Gaussian}]) 
    @test isApplicable(SPEqualityGaussian, [Void, Message{Gaussian}, Message{Gaussian}]) 

    @test ruleSPEqualityGaussian(Message(Gaussian, xi=1.0, w=2.0), Message(Gaussian, xi=3.0, w=4.0), nothing) == Message(Gaussian, xi=4.0, w=6.0)
    @test ruleSPEqualityGaussian(Message(Gaussian, xi=1.0, w=2.0), nothing, Message(Gaussian, xi=3.0, w=4.0)) == Message(Gaussian, xi=4.0, w=6.0)
    @test ruleSPEqualityGaussian(nothing, Message(Gaussian, xi=1.0, w=2.0), Message(Gaussian, xi=3.0, w=4.0)) == Message(Gaussian, xi=4.0, w=6.0)
end

@testset "SPEqualityGamma" begin
    @test SPEqualityGamma <: SumProductRule{Equality}
    @test outboundType(SPEqualityGamma) == Message{Gamma}
    @test isApplicable(SPEqualityGamma, [Message{Gamma}, Message{Gamma}, Void]) 
    @test isApplicable(SPEqualityGamma, [Message{Gamma}, Void, Message{Gamma}]) 
    @test isApplicable(SPEqualityGamma, [Void, Message{Gamma}, Message{Gamma}]) 

    @test ruleSPEqualityGamma(Message(Gamma, a=1.0, b=2.0), Message(Gamma, a=3.0, b=4.0), nothing) == Message(Gamma, a=3.0, b=6.0)
    @test ruleSPEqualityGamma(Message(Gamma, a=1.0, b=2.0), nothing, Message(Gamma, a=3.0, b=4.0)) == Message(Gamma, a=3.0, b=6.0)
    @test ruleSPEqualityGamma(nothing, Message(Gamma, a=1.0, b=2.0), Message(Gamma, a=3.0, b=4.0)) == Message(Gamma, a=3.0, b=6.0)
end

end #module