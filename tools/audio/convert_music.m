% convert_music.m - make Godot-playable OGG copies of the supplied .m4a music.
%
% The supplied .m4a files are fragmented MP4 (DASH) with AAC audio, which neither
% Godot nor MATLAB opens directly. Step 1 (Python, read-only on the source):
%     python tools/audio/fmp4_to_adts.py <in.m4a> <tmp.aac>
% repackages the AAC frames as a plain ADTS stream. Step 2 (this script) decodes
% that stream and writes OGG Vorbis. The original .m4a files are never modified.
%
% Usage (from the repository root):
%     matlab -batch "addpath('tools/audio'); convert_music('<tmp dir>')"
function convert_music(tmp_dir)
    audio = fullfile(pwd, 'plants-vs-zombies', 'assets', 'audio');
    for n = ["menu", "gameplay_music"]
        [y, fs] = audioread(fullfile(tmp_dir, n + ".aac"));
        dst = fullfile(audio, n + ".ogg");
        audiowrite(dst, y, fs, 'Quality', 80);
        fprintf('%s: %.2f s, %d Hz, %d ch -> %s\n', n, size(y, 1) / fs, fs, size(y, 2), dst);
    end
end
