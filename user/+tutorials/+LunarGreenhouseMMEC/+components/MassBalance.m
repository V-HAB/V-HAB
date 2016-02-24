classdef MassBalance < matter.manips.substance.flow
    % This manipulator manages the mass balance inside the plant module 
    % according to the following equation:
    % HWC = HTR + HOP + HCO2P + HWCGR - HOC - HCO2C - HNC
    % Source: "Modified energy cascade model adapted for a multicrop Lunar
    % greenhouse prototype", G. Boscheri et al., 2012, Equation 16.
    % Rearranged for crop growth rate (biomass) it reads:
    % HWCGR = HWC + HOC + HCO2C + HNC - HTR - HOP - HCO2P
    % Now what this manipulator does is it convertes all incoming mass
    % flows into biomass and also substracts all outgoing mass flows from
    % the phase's biomass. This ensures the outgoing biomass is exactly the
    % amount specified by HWCGR while maintaining the mass balance inside
    % the system. This is necessary because the MEC is a mechanistic model
    % and does not exactly represent all physical and chemical processes
    % happening during plant growth. The biomass gained via the MEC growth
    % equation is considered to be a "general" biomass which is later
    % converted into culture specific biomass accordingly.
    
    properties
    end
    
    methods
        function this = MassBalance(oParent, sName)
            this@matter.manips.substance.flow(oParent, sName);
        end
    end
end