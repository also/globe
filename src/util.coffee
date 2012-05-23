class globe.ParticleBuffer
  constructor: (@particles) ->
    @firstParticleIndex = 0
    @newParticleIndex = 0

  allocate: (items, callback) ->
    for item in items
      particle = @particles.particles[@newParticleIndex]
      callback item, particle
      # TODO check if newParticleIndex == firstParticleIndex
      @newParticleIndex = (@newParticleIndex + 1) % @particles.particles.length

  update: (t, callback) ->
    # hide the old particles
    particleIndex = @firstParticleIndex
    loop
      if particleIndex == @newParticleIndex
        break
      nextParticleIndex = (particleIndex + 1) % @particles.particles.length
      particle = @particles.particles[particleIndex]
      if particle.removeT <= t
        particle.setOpacity 0
        if particle.endT <= t
          @firstParticleIndex = nextParticleIndex
      else
        callback? particle
      particleIndex = nextParticleIndex

