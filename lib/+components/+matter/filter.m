classdef filter < matter.store
%FILTER Generic filter model
%   This filter is modeled as a store with two phases, one representing the
%   filter flow volume, the other representing the volume taken up by the
%   material that filters matter from the gas stream through the flow
%   volume. The two phases are connected by two phase-to-phase (p2p)
%   processors.
%   - the filterproc_sorp where the numerical calculation of the sorption
%     process takes place. It also represents the sorption flow 
%   - the filterproc_deso that represents a potential desorption flow

    properties (SetAccess = protected, GetAccess = public)
               
        % Chosen filter type
        sType; 
        
        % Parent system
        oParentSys;
        
        % Void fraction (porosity) to correctly set the volumes
        rVoidFraction;
        
        % Transfer Variables
        % filter size
        fx;fy;fz;       %[m] 
        
        % For plotting
        oProc_sorp;
        oProc_deso;
        
    end
    
    methods
        function this = filter(oParentSys, sName, sType, tParameters)
            % Generic filter class
            %
            % Mandatory input arguments
            % oParentSys    
            % sName
            % sType
            %
            % Optional input arguments. If temperature and pressure are not
            % set, standard values from matter table will be used. 
            % tParameters.fFilterTemperature:   Initial filter temperature
            % tParameters.fFilterPressure:      Initial filter pressure
            % tParameters.fFixedTimeStep:       Fixed time step for phases
            % tParameters.sAtmosphereHelper:    Filter Atmosphere, 
            % tParameters.tGeometry:            Struct with field 'sShape'
            %                                   that determines the shape
            %                                   of the geometric object.
            %                                   Other fields are then shape
            %                                   specific.
            % TODO: Use geometry class here... have to build it first...
            
            
            % Fixed Time Step: 
            %TODO Change this comment... if it works without...
            % the default value of 1 s provided good results for spacesuits.
            % Increase for systems that run longer.
            % Decrease to refine results
            if isfield(tParameters, 'fTimeStep')
                fFixedTimeStep = tParameters.fTimeStep;
            end
            
            if isfield(tParameters, 'sAtmosphereHelper')
                sAtmosphereHelper = tParameters.sAtmosphereHelper;
            else
                sAtmosphereHelper = char();
            end
   
            % Creating a geometry object using the geometry framework.
            % Check for input values
            if isfield(tParameters, 'tGeometry')
                if strcmp('cuboid', tParameters.tGeometry.sShape)
                    % Cuboid: Input parameters are x-, y-, z-dimensions
                    f_x = tParameters.tGeometry.fLength;
                    f_y = tParameters.tGeometry.fWidth;
                    f_z = tParameters.tGeometry.fHeight;
                    fVolume = f_x * f_y * f_z;
                elseif strcmp('cylinder', tParameters.tGeometry.sShape)
                    % Cylinder: Input parameters are diameter, length
                    fVolume = pi * tParameters.tGeometry.fRadius^2 * tParameters.tGeometry.fHeight;
                else
                    error('Filter: The type of filter shape you have entered (%s) is not supported by the Filter. Please use either ''cuboid'' or ''cylinder''.',tParameters.tGeometry.sShape);
                end
            else
                %TODO Create default filter geometry here
            end
            
            % Set the void fraction according to type
            % Assign default values for the size if necessary
            switch sType
                case 'FBA'
                    % Use default values if no size has been assigned
                    if ~exist('oGeo', 'var')
                        % Cylinder: Input parameters are (diameter, length)
                        fVolume = pi * 0.03^2 * 0.3;
                    end
                    rVoidFraction = 0.4;
                    
                case 'RCA'
                    % Use default values if no size has been assinged
                    if ~exist('oGeo', 'var')
                        % Described here is one RCA filter bed, which means
                        % that the actual filter would be twice the size.
                        % Values are reverse engineered. The overall
                        % sorbent volume is given in ICES-2015-313 as   
                        % 715 cm3 per bed. The values below result in a bed
                        % volume of ~0.0011 m3, multiplied by 
                        % (1 - rVoidFraction) this equates to 714.61 cm3,
                        % which is close enough for our purposes.
                        f_x = 0.1692;    %[m]
                        f_y = 0.1097;    %[m]
                        f_z = 0.0586;    %[m]
                        % Cuboid: Input parameters are (x-,y-,z-dimensions)
                        fVolume = f_x * f_y * f_z;
                    end
                    % Setting the void fraction for the SA9T amine sorbent.
                    % Value taken from AIAA-2011-5243.
                    rVoidFraction = 0.343;
                    
                case 'MetOx'    
                    % Use default values if no size has been assinged
                    if ~exist('oGeo', 'var')
                        % fBedVolume  = 0.00269;   % Volume of Bed [m^3]
                        % fFlowVolume = 0.0028;    % Volume of Flow [m^3]
                        % => decided to use a square cuboid
                        f_x = 0.1764;      %[m]
                        f_y = 0.1764;      %[m]
                        f_z = 0.1764;      %[m]
                        % Cuboid: Input parameters are x-, y-, z-dimensions
                        fVolume = f_x * f_y * f_z;
                    end
                    rVoidFraction = 0.510;
         
                otherwise
                    %TODO Remove error message and create a generic filter
                    % instead. 
                    error('Filter: The filter type you have entered (%s) is not available. Please use either ''RCA'', ''FBA'', or ''MetOx''.',sType);
            end              
            
            % Creating a store based on the volume
            this@matter.store(oParentSys, sName, fVolume);
            
            % Temperature
            % can be set individually
            if isfield(tParameters, 'fFilterTemperature')
                fTemperature = tParameters.fFilterTemperature;
            else
                % Default value
                fTemperature = this.oMT.Standard.Temperature;         %[K]
            end
            
            % Temperature
            % can be set individually
            if isfield(tParameters, 'fFilterPressure')
                fPressure = tParameters.fFilterPressure;
            else
                % Default value
                fPressure = this.oMT.Standard.Pressure;         %[K]
            end
            
            % Relative humidity
            % can be set individually
            if isfield(tParameters, 'rRelativeHumidity')
                rRelativeHumidity = tParameters.rRelativeHumidity;
            else
                % Default value
                rRelativeHumidity = 0;         %[K]
            end
            
            % Define parent system as property
            this.oParentSys = oParentSys; 
            
            % Setting the filter type property
            this.sType = sType;
            
            % Assigning the filter's properties (save for setVolume function)
            this.fVolume = fVolume;
            this.rVoidFraction = rVoidFraction;
            
            
            % After superclass constructor is executed, fx, fy and fz
            % can be set (needed in the p2p processor)
            % -------- or --------
            % TODO: add a property for length and cross section in cuboid file!
            if strcmp(sType,'RCA') == 1 || strcmp(sType,'MetOx') == 1
                this.fx = f_x;
                this.fy = f_y;
                this.fz = f_z;
            end
            
            % Creating the phase representing the flow volume
            % gas(oStore, sName, tfMasses, fVolume, fTemp)
            % Check if user wants to use a different inital atmosphere in
            % the filter and does that correctly
            if ~isempty(sAtmosphereHelper)
                try
                    oFlowPhase = this.createPhase(sAtmosphereHelper, 'FlowPhase', this.fVolume * rVoidFraction, fTemperature, rRelativeHumidity, fPressure);
                catch 
                    this.throw('Generic Filter', 'The provided atmosphere helper (%s) is invalid!', sAtmosphereHelper);
                end
            else
                % Otherwise: use SuitAtmosphere as default value
                oFlowPhase = this.createPhase('SuitAtmosphere', 'FlowPhase', this.fVolume * rVoidFraction, fTemperature, rRelativeHumidity, fPressure);
            end
            
            % Creating the phase representing the filter volume manually.
            % gas(oStore, sName, tfMasses, fVolume, fTemp)
            tfMass.AmineSA9T = this.oMT.ttxMatter.AmineSA9T.ttxPhases.tSolid.Density * this.fVolume * (1-this.rVoidFraction);
            matter.phases.mixture(this, 'FilteredPhase', 'solid', tfMass, fTemperature, fPressure);

            % Fixed Time Step
            if exist('fFixedTimeStep','var')
            % Adding fixed time steps for the filter
                tTimeStepProperties.fFixedTimeStep = fFixedTimeStep;
                this.toPhases.FlowPhase.setTimeStepProperties(tTimeStepProperties);
                this.toPhases.FilteredPhase.setTimeStepProperties(tTimeStepProperties);
            end
            
            % Create the according exmes - default for the external
            % connections, i.e. the air stream that should be filtered. The
            % filterports are internal ones for the p2p processor to use.
            matter.procs.exmes.gas(oFlowPhase,     'Inlet');
            matter.procs.exmes.gas(oFlowPhase,     'Outlet');

            % Creating the p2p processor
            % Input parameters: oParentSys, oStore, sName, sPhaseIn, sPhaseOut, (sSpecies, sBed_Name)
            this.oProc_deso = components.matter.filter.FilterProc_deso(this, 'DesorptionProcessor', 'FlowPhase', 'FilteredPhase');
            if strcmp(sType, 'RCA')
                % RCA uses a different sorption processor 
                this.oProc_sorp = components.matter.RCA.RCA_FilterProc_sorp(oParentSys, this, 'SorptionProcessor', 'FlowPhase', 'FilteredPhase', sType);
            else
                this.oProc_sorp = components.matter.filter.FilterProc_sorp(this, 'SorptionProcessor', 'FlowPhase', 'FilteredPhase', sType);
            end
            
        end
        
        function setVolume(this)
            % Overwriting the matter.store setVolume which would give both
            % gas phases the full volume.
            % Flow phase
            this.toPhases.FlowPhase.setVolume(this.fVolume * this.rVoidFraction);
            % Sorbent phase
%             this.toPhases.FilteredPhase.setVolume(this.fVolume * (1-this.rVoidFraction) * 2);
        end
        
    end
end