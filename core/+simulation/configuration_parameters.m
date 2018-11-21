classdef configuration_parameters < base
    %CONFIGURATION_PARAMETERS class framework to provide configuration
    % parameters for simulation. These can be handed into the simulation by
    % a container map through the setup vhab.exec command and are finally
    % stored in this class in simulation.infrastructure and added as
    % property
    
    properties
        ptConfigParams;
    end
    
    methods
        function this = configuration_parameters(ptConfigParams)
            this.ptConfigParams = ptConfigParams;
        end
        
        function configureChild(this, oVsys, sChild, tConfig)
            % Path for oVsys
            % sChild could also be firstChild/secondChild
            % -> concat path/sCHild
            %
            % CHECK if exist - merge structs!
            %
            
            sSysPath = [ simulation.helper.paths.getSysPath(oVsys) '/' sChild ];
            bExists  = this.ptConfigParams.isKey(sSysPath);
            
            if bExists
                tConfig = tools.struct.mergeStructs(this.ptConfigParams(sSysPath), tConfig);
            end
            
            this.ptConfigParams(sSysPath) = tConfig;
        end
        
        function [ tParams, csKeys ] = get(this, oVsys)
            % Return by class, path, ...? placeholders possible?
            % Path Overwrites Class --> MERGE!
            
            sCtor    = oVsys.oMeta.Name;
            sSysPath = simulation.helper.paths.getSysPath(oVsys);
            
            csKeys  = this.ptConfigParams.keys();
            tParams = struct();
            
            % Check by constructor
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
            
            csKeys = fieldnames(tParams);
        end
        
        function sCode = configCode(this, oVsys)
            % Code that can directly be eval'd
            
            % oVsys param just precautionary for now, maybe needed at some
            % point
            
            %TODO allow fully recursive setting of sub-params? I.e. some-
            %thing like this.oSubObj.oSubSubObj.tStructAttr.xKey = 'asd';
            %sCode = '[ tC csN ] = this.oRoot.oCfgParams.get(this); for iP = 1:length(csN), this.(csN{iP}) = tC.(csN{iP}); end;';
            
            sCode = '[ tC csN ] = this.oRoot.oCfgParams.get(this); for iP = 1:length(csN), if ~isempty(strfind(csN{iP}, ''.'')), [ sA, sB ] = strtok(csN{iP}, ''.''); this.(sA).(sB(2:end)) = tC.(csN{iP}); else, this.(csN{iP}) = tC.(csN{iP}); end; end;';
        end
    end
    
end

