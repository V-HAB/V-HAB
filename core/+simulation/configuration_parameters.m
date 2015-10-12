classdef configuration_parameters < base
    %CONFIGURATION_PARAMETERS Summary of this class goes here
    %   Detailed explanation goes here
    %
    %TODO also by system name?
    
    properties
        ptConfigParams;
    end
    
    methods
        function this = configuration_parameters(ptConfigParams)
            this.ptConfigParams = ptConfigParams;
        end
        
        function [ tParams, csKeys ] = get(this, oVsys)
            % Return by class, path, ...? placeholders possible?
            % Path Overwrites Class --> MERGE!
            
            sCtor    = oVsys.oMeta.Name;
            sSysPath = simulation.helper.paths.getSysPath(oVsys);
            %TODO -> also check parent class Ctors!
            
            csKeys  = this.ptConfigParams.keys();
            tParams = struct();
            
            % Check by CTOR
            for iP = 1:length(csKeys)
                if strcmp(csKeys{iP}, sCtor)
                    tParams = tools.struct.mergeStructs(tParams, this.ptConfigParams(csKeys{iP}));
                end
            end
            
            % By Path!
            for iP = 1:length(csKeys)
                sKey = simulation.helper.paths.convertShorthandToFullPath(csKeys{iP});
                
                if strcmp(sKey, sSysPath)
                    tParams = tools.struct.mergeStructs(tParams, this.ptConfigParams(csKeys{iP}));
                end
            end
            
            
            %TODO also check vsys sName?
            
            csKeys = fieldnames(tParams);
            
            %TODO
            % get CTOR name, generate path
            % init empty struct
            % check if ctor in ptCfgParams -> merge on struct
            % check if path/full path in ptCfgParams -> merge on struct
            %       ( loop ptCfgParam keys, each key - fullPath - check)
            % return struct
        end
        
        function sCode = configCode(this, oVsys)
            % Code that can directly be eval'd
            
            % oVsys param just precautionary for now, maybe needed at some
            % point
            
            sCode = '[ tC csN ] = this.oRoot.oCfgParams.get(this); for iP = 1:length(csN), this.(csN{iP}) = tC.(csN{iP}); end;';
        end
    end
    
end

