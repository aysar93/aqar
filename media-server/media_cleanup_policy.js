'use strict';

// Never infer absence of references from a periodic scan alone. The deployment
// adapter must hold an exclusive barrier honored by EVERY reference writer.
// Legacy writer coverage is false until separately proven at deployment time.
async function cleanupUnreferencedMedia(candidate, deps) {
  if (!candidate || !/^uploads\/(public|private)\//.test(candidate.path || '') ||
      candidate.path.includes('..') || !/^[1-9][0-9]*$/.test(String(candidate.generation))) {
    return {deleted: false, reason: 'protected_or_invalid_object'};
  }
  if (deps.allReferenceWritersCovered !== true || typeof deps.withExclusiveBarrier !== 'function') {
    return {deleted: false, reason: 'writer_coverage_unproven'};
  }
  return deps.withExclusiveBarrier(candidate.path, async barrier => {
    if (!barrier || barrier.held !== true) return {deleted: false, reason: 'barrier_not_held'};
    const snapshot = await barrier.references();
    if (!snapshot.complete || snapshot.references.length || snapshot.pendingUploads !== 0) {
      return {deleted: false, reason: 'referenced_or_pending'};
    }
    const metadata = await deps.metadata(candidate.path);
    if (String(metadata.generation) !== String(candidate.generation)) return {deleted: false, reason: 'generation_changed'};
    const recovery = await deps.backupAndVerify(candidate.path, metadata.generation);
    if (!recovery.encrypted || !recovery.verified || recovery.sha256 !== metadata.sha256) {
      return {deleted: false, reason: 'recovery_not_verified'};
    }
    const final = await barrier.references();
    if (!final.complete || final.revision !== snapshot.revision || final.references.length || final.pendingUploads !== 0) {
      return {deleted: false, reason: 'reference_race'};
    }
    await deps.deleteGeneration(candidate.path, String(metadata.generation));
    return {deleted: true, generation: String(metadata.generation), recovery: recovery.id};
  });
}
module.exports = {cleanupUnreferencedMedia};
