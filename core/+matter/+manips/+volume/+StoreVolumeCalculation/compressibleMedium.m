classdef compressibleMedium < matter.manips.volume.step
    % This volume manipulator identifies a phase as compressible and
    % handles the required volume calculations with respect to other phases
    % to respect the compressible nature of this phase
    
    properties (Constant)
        % Identifies this manipualtor as a stationary volume manipulator
        bCompressible = true;
    end
    
    methods
        function this = compressibleMedium(sName, oPhase)
            this@matter.manips.volume.step(sName, oPhase);
        end
        
        function update(this, fNewVolume, fNewPressure)
            % This function calculates the necessary volume change of this
            % phase 
            
            fElapsedTime = this.oTimer.fTime - this.fLastExec;
            
            if fElapsedTime > 0
                if nargin > 1
                    % In this case the manip was handed the volume from
                    % another compressibleMedium manipulator in the same
                    % store and we do not have to perform all of the
                    % calculation but can just set the volume
                    update@matter.manips.volume(this, fNewVolume, fNewPressure);
                    
                elseif this.oPhase.bUpdateRegistered
                    % to reduce the impact of this module on the calculation
                    % time the update will only be performed if the phase will
                    % update anyway. Since the manipulators are also registered
                    % for an update if the phase update is registered, it is
                    % also ensured that this update will be called when the
                    % phase update is called.
                    afDensityIncompressiblePhase = zeros(1, this.oPhase.oStore.iPhases);
                    afVolumeIncompressiblePhase  = zeros(1, this.oPhase.oStore.iPhases);
                    abCompressiblePhase          = false(1, this.oPhase.oStore.iPhases);
                    for iPhase = 1: this.oPhase.oStore.iPhases
                        % if this manipulator is used every phase in the store
                        % must have either the compressibleMedium or the
                        % incompressibleMedium volume manipulator!
                        oOtherPhase = this.oPhase.oStore.aoPhases(iPhase);
                        if ~oOtherPhase.toManips.volume.bCompressible
                            % Note that we handle these phases like
                            % incompressible phases because otherwise an
                            % iteration would be necessary. However, we
                            % actually perform a calculation that is in between
                            % the compressible and incompressible assumption
                            % because the calculateDensity function actually
                            % changes depending on the current pressure in the
                            % phase. What we do assume is that the density of
                            % the "incompressible" substances does not change
                            % significantly over the pressure and therefore the
                            % small pressure differences that occur over one
                            % phase update only have a negligible impact
                            afDensityIncompressiblePhase(iPhase) = this.oMT.calculateDensity(oOtherPhase);
                            afVolumeIncompressiblePhase(iPhase)  = oOtherPhase.fMass / afDensityIncompressiblePhase(iPhase);
                        else
                            abCompressiblePhase(iPhase) = true;
                        end
                    end

                    fRemainingVolume = this.oPhase.oStore.fVolume - sum(afVolumeIncompressiblePhase);
                    % It is possible that negative values occur if too much liquid was
                    % allowed to flow into the store, or too much solid was added! If
                    % that happens we tell the user to decrease the time step of the
                    % store or provide another limitation (e.g. use exec to limit
                    % liquid volume)
                    if fRemainingVolume < 0
                        error('the time step was too large and the calculate compressible volume in store %s became smaller than zero because of incompressible phases!', this.sName)
                    end

                    iCompressiblePhases = sum(abCompressiblePhase);
                    if iCompressiblePhases > 1
                        %% Calculation for multiple compressible phases
                        % In case multiple compressible phases are present
                        % within the store at the same time, it is necessary to
                        % calculate the distribution of the remaining volume
                        % between the compressible phases. The important part
                        % with that calculation is that the values for
                        % densities that the matter table provides and the
                        % fMass/fVolume values of each of the phases match
                        % closely to have a consistent simulation. Therefore we
                        % calculate the density of each compressible medium and
                        % use it to derive its portion of the remaining volume.
                        % Basically we calculate the volume the phase would
                        % like to occupy and give it the proportionate chunk of
                        % the available volume

                        aiCompressiblePhase = find(abCompressiblePhase);
                        
                        % First we get the current values for only the
                        % compressible phases
                        afDensityCompressiblePhase   = zeros(1, iCompressiblePhases);
                        afMassCompressiblePhase      = zeros(1, iCompressiblePhases);
                        afVolumeCompressiblePhase    = zeros(1, iCompressiblePhases);
                        afPressureCompressiblePhase  = zeros(1, iCompressiblePhases);
                        coCompressiblePhase          = cell(1,2);
                        for iCompressiblePhase = 1:iCompressiblePhases
                            coCompressiblePhase{iCompressiblePhase} = this.oPhase.oStore.aoPhases(aiCompressiblePhase(iCompressiblePhase));

                            if coCompressiblePhase{iCompressiblePhase} == this.oPhase
                                iCurrentPhase = iCompressiblePhase;
                            end
                            afDensityCompressiblePhase(iCompressiblePhase)  = this.oMT.calculateDensity(coCompressiblePhase{iCompressiblePhase});
                            afMassCompressiblePhase(iCompressiblePhase)     = coCompressiblePhase{iCompressiblePhase}.fMass ;
                            afVolumeCompressiblePhase(iCompressiblePhase)   = coCompressiblePhase{iCompressiblePhase}.fMass / afDensityCompressiblePhase(iCompressiblePhase);
                            afPressureCompressiblePhase(iCompressiblePhase) = coCompressiblePhase{iCompressiblePhase}.fPressure;
                        end
                        
                        % The initial guess is that each compressible phase
                        % will receive the same portion of the remaining volume
                        % it had before
                        afVolumesBoundary1 = (afVolumeCompressiblePhase ./ sum(afVolumeCompressiblePhase)) .* fRemainingVolume;
                        
                        % Now we calculate the new densities that result
                        % from this guess
                        afNewDensities = afMassCompressiblePhase ./ afVolumesBoundary1;
                        
                        % Using the matter table the new pressures of the
                        % initial guess are calculated. These are
                        % considered the first error for the nested
                        % intervall approach that is employed hereafter
                        afNewPressure           = zeros(1, iCompressiblePhases);
                        for iCompressiblePhase = 1:iCompressiblePhases
                            afNewPressure(iCompressiblePhase) = this.oMT.calculatePressure(coCompressiblePhase{iCompressiblePhase}.sType, coCompressiblePhase{iCompressiblePhase}.afMass, coCompressiblePhase{iCompressiblePhase}.fTemperature, afNewDensities(iCompressiblePhase));
                        end
                        afError1 = afNewPressure - mean(afNewPressure);
                        
                        % To prepare for the nested intervall approach we
                        % first iterate the volume roughly so that we find
                        % two valid boundaries for the nested intervall
                        % approach
                        afError2 = afError1;
                        iCounter = 0;
                        iMaxIterations = 100;
                        afVolumesBoundary2 = afVolumesBoundary1;
                        while any(sign(afError1) == sign(afError2)) && iCounter < iMaxIterations
                            % The iteration is based on the sign of the
                            % pressures of the phases compared to the
                            % average pressure. Since a pressure smaller
                            % then the average pressure suggests that the
                            % phase received too much volume, while a
                            % higher pressure suggests it received too
                            % little volume. The phases that received too
                            % little volume are then increased in volume by
                            % the fraction of 0.1% that can be attributed
                            % to the difference they had to the average
                            % pressure
                            aiSigns = sign(afError2);
                            aiPositiveSigns = find(aiSigns == 1);
                            aiNegativeeSigns = find(aiSigns == -1);
                            
                            afVolumesBoundary2(aiPositiveSigns) = afVolumesBoundary2(aiPositiveSigns) .* 1.00001 .* (afError2(aiPositiveSigns) ./ sum(afError2(aiPositiveSigns)));
                            afVolumesBoundary2(aiNegativeeSigns) = afVolumesBoundary2(aiNegativeeSigns) .* 0.99999 .* (afError2(aiNegativeeSigns) ./ sum(afError2(aiNegativeeSigns)));

                            % To ensure that we do not change the available
                            % volume through numerical errors, we average
                            % the volumes and use the initial parameter to
                            % calculate the new volumes
                            afVolumesBoundary2 = (afVolumesBoundary2 ./ sum(afVolumesBoundary2)) .* fRemainingVolume;

                            % now we can calculate the new densities and
                            % with those also the new pressures and iterate
                            % if necessary.
                            afNewDensities = afMassCompressiblePhase ./ afVolumesBoundary2;
                            
                            afNewPressure           = zeros(1, iCompressiblePhases);
                            for iCompressiblePhase = 1:iCompressiblePhases
                                afNewPressure(iCompressiblePhase) = this.oMT.calculatePressure(coCompressiblePhase{iCompressiblePhase}.sType, coCompressiblePhase{iCompressiblePhase}.afMass, coCompressiblePhase{iCompressiblePhase}.fTemperature, afNewDensities(iCompressiblePhase));
                            end
                            afError2 = afNewPressure - mean(afNewPressure);
                            
                            % To prevent infinite loops we have a counter
                            % and throw an eeror if we exceed the limit
                            iCounter = iCounter + 1;
                        end
                        if iCounter >= iMaxIterations
                            error('The compressible medium calculation ran into a max iteration error')
                        end
                        
                        % Now we use a nested interval approach to find the
                        % phase volumina at which all phases have the same
                        % pressure. Currently this calculation is tested
                        % for 1 gas and 1 liquid phase. In theory it should
                        % work for any combination, but there are many
                        % things that can go wrong. TBD: Built a check for
                        % that
                        iIteration = 0;
                        fError = 1;
                        while fError > 1e-3 && iIteration < iMaxIterations
                            
                            % The first step of the nested interval
                            % approach is to half the interval and
                            % calculate the values at the middle of the
                            % current interval
                            afNewVolumes    = (afVolumesBoundary1 + afVolumesBoundary2) ./ 2;
                            afNewDensities  = afMassCompressiblePhase ./ afNewVolumes;
                            afNewPressure           = zeros(1, iCompressiblePhases);
                            for iCompressiblePhase = 1:iCompressiblePhases
                                afNewPressure(iCompressiblePhase) = this.oMT.calculatePressure(coCompressiblePhase{iCompressiblePhase}.sType, coCompressiblePhase{iCompressiblePhase}.afMass, coCompressiblePhase{iCompressiblePhase}.fTemperature, afNewDensities(iCompressiblePhase));
                            end
                            fNewPressure = mean(afNewPressure);
                            afError = afNewPressure - fNewPressure;
                            
                            % Then we check if the signs of the error are
                            % identical to the first or the second error
                            % and replace the boundary whose signs are
                            % matched
                            if all(sign(afError) == sign(afError1))
                                afError1 = afError;
                                afVolumesBoundary1 = afNewVolumes;
                            elseif all(sign(afError) == sign(afError2))
                                afError2 = afError;
                                afVolumesBoundary2 = afNewVolumes;
                            else
                                % I am not quite sure if this is an edge
                                % case that could happen. If we are sure
                                % that it cannot happen, we can remove this
                                % part and have only one if condition
                                % above. But otherwise wrong results might
                                % not be detected.
                                keyboard()
                            end
                            
                            fError = max(abs(afError));
                            
                            % As before a counter prevents an infinite loop
                            % in the iteration
                            iIteration = iIteration + 1;
                        end
                        if iIteration >= iMaxIterations
                            error('The compressible medium calculation ran into a max iteration error')
                        end
                        
                        fVolumeThisPhase = afNewVolumes(iCurrentPhase);
                        
                    else
                        %% Calculation for only one compressible phase
                        % If there is only one compressible phase, the
                        % calculation is simple. All of the remaining volume
                        % belongs to the compressible phase
                        fVolumeThisPhase = fRemainingVolume;
                        
                        fNewPressure = this.oPhase.fPressure;
                    end

                    % since the update of the phase is executed after this
                    % manipulator update anyway, we do not also recalculate the
                    % pressure, since 
                    update@matter.manips.volume(this, fVolumeThisPhase);
                    
                    % Now we also update all other phases within the same
                    % store as we already have the required values anyway:
                    
                    for iPhase = 1: this.oPhase.oStore.iPhases
                        % if this manipulator is used every phase in the store
                        % must have either the compressibleMedium or the
                        % incompressibleMedium volume manipulator!
                        oOtherPhase = this.oPhase.oStore.aoPhases(iPhase);
                        if iCompressiblePhases > 1 && oOtherPhase.toManips.volume.bCompressible
                            % Since we cannot be sure that the update for
                            % all compressible phases will be executed, we
                            % set the new volume and pressure values. TBC
                            % we could also trigger an update for all
                            % compressible phases instead of setting the
                            % pressure.
                            % Only set this for the manips which are not
                            % the current manip
                            if aiCompressiblePhase(iPhase) ~= iCurrentPhase
                                oOtherPhase.toManips.volume.update(afNewVolumes(aiCompressiblePhase(iPhase)), fNewPressure);
                            end
                        else
                            % For incompressible phases we set the volumes
                            % calculated from the matter table density and
                            % their current mass
                            oOtherPhase.toManips.volume.update(afVolumeIncompressiblePhase(iPhase), fNewPressure);
                        end
                    end
                end
            end
        end
            
        function reattachManip(this, oPhase)
            % Since the compressibleMedium manipulator must bind certain
            % update events to the phase and other manipulators we must
            % overload the attachManip function of
            % matter.manips.volume.stationary with this function. The
            % original function is still executed, as all of these
            % operations are necessary as well but additionally required
            % triggers are set. Note that on detaching the manip all event
            % triggers are deleted anyway, and therfore that function must
            % not be overloaded. The necessary inputs are:
            % oPhase:   a phase object which fullfills the required phase
            %           condition of the manip specified in the
            %           sRequiredType property.
            reattachManip@matter.manips.volume(this, oPhase);
           
            % bind the update function to the update of the connected
            % phase, as changes in the compressible phase result in
            % pressure changes which makes a recalculation necessary
            this.oPhase.bind('update_post', @this.update);
        end
    end
end