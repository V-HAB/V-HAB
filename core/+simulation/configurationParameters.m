classdef configurationParameters < base
    %CONFIGURATIONPARAMETERS class framework to provide configuration parameters for simulations
    % These can be handed into the simulation by a container map through
    % the setup vhab.exec command and are finally stored in this class in
    % simulation.infrastructure and added as property. The idea here is to
    % make it easier to run multiple simulations in parallel that each use
    % different parameters for vsys objects. In the parfor() loop that
    % initializes the parallel simulations, an array of configuration
    % parameter objects is passed in and each simulation then uses it's
    % individual set of parameters. 
    
    properties
        % A containersMap() object conainting the names of the vsys object
        % properties and the values that are to be set. 
        ptConfigParams;
    end
    
    methods
        function this = configurationParameters(ptConfigParams)
            % Setting the property
            this.ptConfigParams = ptConfigParams;
        end
        
        function [ tParams, csKeys ] = get(this, oVsys)
            %GET Extracts the configuration parameters for a specific system
            % In the containersMap() variable the system objects within a
            % model are referenced as strings. These strings can either
            % contain the path to the constructor of the vsys object (e.g. 
            % 'tutorials.simple_flow.systems.Example') or the shorthand for
            % the system object's path within the model (e.g.
            % 'Example/Subsystem'). This method will check for both
            % possibilities and return the parameters for each system as a
            % struct. 
            % For added convenience on the user side, the field names of
            % the struct are also returned. 
            % Users should note that if both methods of referencing are
            % used for the same object, then the parameter values that are
            % associated with the object path will overwrite the ones given
            % with the constructor path. This is due to the operation of
            % the tools.struct.mergeStructs() method. 
            
            % Extracting the constructor name from the system object.
            sConstructor = oVsys.oMeta.Name;
            
            % Using the helper to extract the path to this vsys object.
            sSystemPath = simulation.helper.paths.getSystemPath(oVsys);
            
            % Getting the keys for all system objects referenced in the
            % configuration parameters map.
            csSystems  = this.ptConfigParams.keys();
            
            % Initializing the return variable that will contain the
            % parameters
            tParams = struct();
            
            % Looping through the keys to see if there is a matching
            % constructor path.
            for iP = 1:length(csSystems)
                if strcmp(csSystems{iP}, sConstructor)
                    % We found a matching constructor path, so we add the
                    % parameters to the return variable.
                    tParams = tools.struct.mergeStructs(tParams, this.ptConfigParams(csSystems{iP}));
                end
            end
            
            % Looping through the keys to see if there is a matching system
            % path.
            for iP = 1:length(csSystems)
                % First we need to convert the system path, which is given
                % in shorthand (e.g. 'Example/Subsystem') to the full path
                % (e.g. 'Example.toChildren.Subsystem').
                sKey = simulation.helper.paths.convertShorthandToFullPath(csSystems{iP});
                
                if strcmp(sKey, sSystemPath)
                    % We found a matching system path, so we add the
                    % parameters to the return variable. If the same
                    % parameters were also defined using the constructor
                    % path, then they will be overwritten here. 
                    tParams = tools.struct.mergeStructs(tParams, this.ptConfigParams(csSystems{iP}));
                end
            end
            
            % For added user convenience, the fieldnames are extracted here
            % and returned as well. 
            csKeys = fieldnames(tParams);
        end
        
        function sCode = configCode(this, oVsys)  %#ok<INUSD>
            %CONFIGCODE Returns code that can be directly evaluated in the vsys object
            % The execution of this code will actually set the parameters
            % on the vsys objects. 
            % For now this code is just a static string variable. However,
            % in the future it may be desired to more dynamically generate
            % this code and possibly provide the capability to recursively
            % set parameters on child systems as well. That is why this is
            % a method in the first place and not hard coded and this is
            % also the reason the oVsys parameter is passed in. 
            
            %TODO allow fully recursive setting of sub-params? I.e. some-
            %thing like this.oSubObj.oSubSubObj.tStructAttr.xKey = 'asd';
            %sCode = '[ tC csN ] = this.oRoot.oCfgParams.get(this); for iP = 1:length(csN), this.(csN{iP}) = tC.(csN{iP}); end;';
            
            sCode = [ ...
            ... Getting the parameters and keys for the current object
            '[ tParams, csKeys ] = this.oRoot.oCfgParams.get(this);           ', ...
            ...
            ... Looping through all parameters
            'for iParameter = 1:length(csKeys),                                ', ...
            ... If there is a dot ('.') character in the key string, we 
            ... need to separate the string to set the parameter. An 
            ... example would be to set values in a struct property. The 
            ... string in csKeys could then read 'toFlowRates.Inlet'.
            '    if ~isempty(strfind(csKeys{iParameter}, ''.'')),              ', ...
            '        [ sA, sB ] = strtok(csKeys{iParameter}, ''.'');           ', ...
            '        this.(sA).(sB(2:end)) = tParams.(csKeys{iParameter});     ', ...
            '    else,                                                         ', ...
            ...      The string has no dot ('.') character, so we can just 
            ...      set the appropriate parameter directly.
            '        this.(csKeys{iParameter}) = tParams.(csKeys{iParameter}); ', ...
            '    end;                                                          ', ...
            'end;                                                              '];
        end
    end
    
end

