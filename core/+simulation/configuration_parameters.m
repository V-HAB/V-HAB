classdef configuration_parameters < base
    %CONFIGURATION_PARAMETERS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ptConfigParams;
    end
    
    methods
        function this = configuration_parameters(ptConfigParams)
            this.ptConfigParams = ptConfigParams;
        end
        
        function tParams = get(this, oVsys)
            % Return by class, path, ...? placeholders possible?
            % Path Overwrites Class --> MERGE!
        end
        
        function sCode = getCode(this, oVsys)
            % Code that can directly be eval'd
            
            sCode = '[ tC csN ] = this.oSim.oCfgParams.get(this); for iP = 1:length(csN), this.(csN{iP}) = tC.(csN{iP}); end;';
        end
    end
    
end

